const { ethers } = require("ethers");

/**
 * OmniLease Manager
 * Handles pricing logic and on-chain state indexing.
 */
class LeaseManager {
    constructor() {
        // Fallback to public RPC for MVP; in production use environment variables
        this.provider = new ethers.JsonRpcProvider(process.env.RPC_URL || "https://eth-mainnet.g.alchemy.com/v2/demo");
        
        // Base rates for the MVP (in USDC units, assuming 6 decimals)
        this.BASE_RATE_PER_DAY = 5000000n; // $5.00
        this.SCARCITY_MULTIPLIER = 120n;   // 1.2x
    }

    /**
     * Calculate a lease quote based on duration and asset tier.
     * @param {string} collection - NFT contract address
     * @param {number} durationDays - Number of days to lease
     * @returns {Object} Quote details
     */
    async getQuote(collection, durationDays) {
        if (durationDays <= 0) throw new Error("Duration must be positive");
        
        // Mock scarcity check: if address ends in '0', it's "rare"
        const isRare = collection.toLowerCase().endsWith("0");
        const multiplier = isRare ? this.SCARCITY_MULTIPLIER : 100n;
        
        const totalPrice = (this.BASE_RATE_PER_DAY * BigInt(durationDays) * multiplier) / 100n;
        
        return {
            collection,
            durationDays,
            quoteId: ethers.hexlify(ethers.randomBytes(16)),
            priceUSDC: totalPrice.toString(),
            expiry: Math.floor(Date.now() / 1000) + (durationDays * 86400),
            isRare
        };
    }

    /**
     * Check the status of a lease on-chain.
     * @param {string} registryAddress - The LeaseRegistry contract address
     * @param {string} tokenId - The NFT ID
     */
    async getLeaseStatus(registryAddress, tokenId) {
        try {
            // Minimal ABI for the LeaseRegistry
            const abi = [
                "function getLeaseInfo(uint256 tokenId) external view returns (address owner, address renter, uint64 expiry, bool active)"
            ];
            const contract = new ethers.Contract(registryAddress, abi, this.provider);
            
            const [owner, renter, expiry, active] = await contract.getLeaseInfo(tokenId);
            
            return {
                tokenId,
                owner,
                renter,
                expiry: Number(expiry),
                active,
                isExpired: Number(expiry) < Math.floor(Date.now() / 1000)
            };
        } catch (error) {
            console.error("Indexing Error:", error);
            // Return mock data if provider fails to ensure API doesn't crash during demo
            return {
                tokenId,
                error: "Contract call failed",
                mockStatus: "Available"
            };
        }
    }
}

module.exports = new LeaseManager();