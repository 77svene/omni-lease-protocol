const { ethers } = require("ethers");

/**
 * VaultWatcher: Listens to LeaseRegistry and individual Vault events.
 * Maintains an in-memory state for the MVP.
 */
class VaultWatcher {
    constructor(rpcUrl, registryAddress, registryAbi, vaultAbi) {
        this.provider = new ethers.JsonRpcProvider(rpcUrl);
        this.registry = new ethers.Contract(registryAddress, registryAbi, this.provider);
        this.vaultAbi = vaultAbi;
        this.vaults = new Map(); // vaultAddress -> metadata
        this.activeLeases = [];
    }

    async start() {
        console.log("Starting VaultWatcher...");
        
        // Listen for new vaults being deployed
        this.registry.on("VaultCreated", async (vaultAddress, owner, nftContract) => {
            console.log(`New Vault Detected: ${vaultAddress} for NFT ${nftContract}`);
            this.trackVault(vaultAddress, nftContract, owner);
        });

        // Sync existing vaults (simplified for MVP)
        // In production, we'd query logs from block 0 or a checkpoint
    }

    async trackVault(address, nftContract, owner) {
        const vaultContract = new ethers.Contract(address, this.vaultAbi, this.provider);
        
        this.vaults.set(address, {
            address,
            nftContract,
            owner,
            status: "ACTIVE",
            lastUpdate: Date.now()
        });

        // Listen for Lease events on this specific vault
        vaultContract.on("LeaseCreated", (tokenId, renter, expiry, price) => {
            const lease = {
                vault: address,
                nftContract,
                tokenId: tokenId.toString(),
                renter,
                expiry: Number(expiry),
                price: ethers.formatEther(price),
                timestamp: Date.now()
            };
            this.activeLeases.push(lease);
            console.log(`Lease Created: NFT ${tokenId} rented by ${renter} until ${new Date(Number(expiry) * 1000).toISOString()}`);
        });
    }

    getVaultStatus(id) {
        return this.vaults.get(id) || { status: "NOT_FOUND" };
    }

    getActiveLeases() {
        const now = Math.floor(Date.now() / 1000);
        return this.activeLeases.filter(l => l.expiry > now);
    }
}

module.exports = VaultWatcher;