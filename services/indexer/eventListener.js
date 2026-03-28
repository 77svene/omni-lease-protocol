const { ethers } = require("ethers");
const { updateLease, terminateLease, getSyncStatus, updateSyncStatus } = require("./dbSchema");

/**
 * OmniLease Event Listener
 * Connects to the LeaseRegistry contract and indexes events into the local DB.
 */
class EventListener {
    constructor(rpcUrl, registryAddress, abi) {
        this.provider = new ethers.JsonRpcProvider(rpcUrl);
        this.registry = new ethers.Contract(registryAddress, abi, this.provider);
    }

    async start() {
        console.log("Starting OmniLease Event Listener...");
        
        // 1. Get last synced block
        const status = await getSyncStatus();
        let startBlock = status.lastBlock + 1;
        const currentBlock = await this.provider.getBlockNumber();

        if (startBlock > currentBlock) {
            startBlock = currentBlock;
        }

        console.log(`Syncing from block ${startBlock} to ${currentBlock}`);

        // 2. Catch up on missed events
        await this.syncHistoricalEvents(startBlock, currentBlock);

        // 3. Listen for live events
        this.registry.on("LeaseCreated", async (leaseId, lister, lessee, collection, tokenId, expiry, event) => {
            console.log(`New Lease: ${leaseId} for Token ${tokenId}`);
            await updateLease({
                leaseId: leaseId.toString(),
                lister,
                lessee,
                collection,
                tokenId: tokenId.toString(),
                expiry: Number(expiry),
                status: "ACTIVE"
            });
            await updateSyncStatus(event.blockNumber);
        });

        this.registry.on("LeaseTerminated", async (leaseId, event) => {
            console.log(`Lease Terminated: ${leaseId}`);
            await terminateLease(leaseId.toString());
            await updateSyncStatus(event.blockNumber);
        });
    }

    async syncHistoricalEvents(from, to) {
        if (from >= to) return;

        const createdFilter = this.registry.filters.LeaseCreated();
        const terminatedFilter = this.registry.filters.LeaseTerminated();

        const createdEvents = await this.registry.queryFilter(createdFilter, from, to);
        for (const event of createdEvents) {
            const { leaseId, lister, lessee, collection, tokenId, expiry } = event.args;
            await updateLease({
                leaseId: leaseId.toString(),
                lister,
                lessee,
                collection,
                tokenId: tokenId.toString(),
                expiry: Number(expiry),
                status: "ACTIVE"
            });
        }

        const terminatedEvents = await this.registry.queryFilter(terminatedFilter, from, to);
        for (const event of terminatedEvents) {
            const { leaseId } = event.args;
            await terminateLease(leaseId.toString());
        }

        await updateSyncStatus(to);
        console.log(`Historical sync complete up to block ${to}`);
    }
}

// Export for service runner
module.exports = EventListener;

// If run directly (for testing/standalone)
if (require.main === module) {
    const RPC_URL = process.env.RPC_URL || "http://127.0.0.1:8545";
    const REGISTRY_ADDR = process.env.REGISTRY_ADDRESS;
    const ABI = [
        "event LeaseCreated(bytes32 indexed leaseId, address indexed lister, address indexed lessee, address collection, uint256 tokenId, uint256 expiry)",
        "event LeaseTerminated(bytes32 indexed leaseId)"
    ];

    if (!REGISTRY_ADDR) {
        console.error("REGISTRY_ADDRESS env var required");
        process.exit(1);
    }

    const listener = new EventListener(RPC_URL, REGISTRY_ADDR, ABI);
    listener.start().catch(err => {
        console.error("Listener failed:", err);
        process.exit(1);
    });
}