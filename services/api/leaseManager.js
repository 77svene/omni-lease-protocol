const { ethers } = require("ethers");

/**
 * LeaseManager: Handles the business logic for querying active leases
 * from the LeaseRegistry and ShadowFactory contracts.
 */
class LeaseManager {
    constructor(rpcUrl, registryAddress, factoryAddress) {
        this.provider = new ethers.JsonRpcProvider(rpcUrl);
        this.registryAddress = registryAddress;
        this.factoryAddress = factoryAddress;
        
        // Minimal ABI for the Registry and Factory
        this.registryAbi = [
            "function getLease(uint256 tokenId) external view returns (address lessee, uint64 expiry, bool active)",
            "function isLeaseValid(uint256 tokenId) external view returns (bool)"
        ];
        this.factoryAbi = [
            "function getOriginalAsset(uint256 shadowId) external view returns (address collection, uint256 originalId)"
        ];

        this.registry = new ethers.Contract(registryAddress, this.registryAbi, this.provider);
        this.factory = new ethers.Contract(factoryAddress, this.factoryAbi, this.provider);
    }

    /**
     * Resolves a Shadow NFT ID to its original asset details and lease status.
     * @param {string} shadowId - The ID of the Shadow NFT.
     * @returns {Promise<Object>} Asset and lease details.
     */
    async getLeaseStatus(shadowId) {
        try {
            // 1. Map Shadow ID back to Original Asset
            const [collection, originalId] = await this.factory.getOriginalAsset(shadowId);
            
            if (collection === ethers.ZeroAddress) {
                throw new Error("Shadow NFT not found or unlinked");
            }

            // 2. Check Lease Status in Registry
            const [lessee, expiry, active] = await this.registry.getLease(originalId);
            const isValid = await this.registry.isLeaseValid(originalId);

            return {
                shadowId,
                originalCollection: collection,
                originalId: originalId.toString(),
                lessee,
                expiry: Number(expiry),
                active,
                isValid,
                timestamp: Math.floor(Date.now() / 1000)
            };
        } catch (error) {
            console.error(`LeaseManager Error [${shadowId}]:`, error.message);
            return null;
        }
    }

    /**
     * Fetches the original NFT metadata URI to proxy it.
     * @param {string} collection - Original NFT contract address.
     * @param {string} tokenId - Original Token ID.
     */
    async getOriginalMetadata(collection, tokenId) {
        const erc721Abi = ["function tokenURI(uint256 tokenId) external view returns (string)"];
        const contract = new ethers.Contract(collection, erc721Abi, this.provider);
        try {
            return await contract.tokenURI(tokenId);
        } catch (e) {
            return null;
        }
    }
}

module.exports = LeaseManager;