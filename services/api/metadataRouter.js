const express = require('express');
const router = express.Router();
const leaseManager = require('./leaseManager');

/**
 * OmniLease Metadata Proxy
 * GET /metadata/:shadowAddress/:tokenId
 * 
 * This endpoint is set as the baseURI for Shadow NFTs.
 * It resolves the underlying original NFT from the LeaseRegistry
 * and fetches its real metadata to ensure seamless utility.
 */
router.get('/:shadowAddress/:tokenId', async (req, res) => {
    const { shadowAddress, tokenId } = req.params;

    try {
        // 1. Identify the original asset via the LeaseRegistry
        // In a production environment, we'd query the ShadowFactory/Registry contracts.
        // For the MVP, we use the leaseManager to resolve the mapping.
        const leaseInfo = await leaseManager.getLeaseInfo(shadowAddress, tokenId);

        if (!leaseInfo || !leaseInfo.active) {
            return res.status(404).json({
                error: "Lease expired or Shadow NFT invalid",
                attributes: [{ trait_type: "Status", value: "Expired" }]
            });
        }

        // 2. Fetch original metadata from the source (IPFS/Web2 URL)
        // leaseInfo contains { originalCollection, originalTokenId, metadataUrl }
        const response = await fetch(leaseInfo.metadataUrl);
        if (!response.ok) throw new Error("Failed to fetch original metadata");
        
        const originalMetadata = await response.json();

        // 3. Inject Shadow-specific traits while preserving original utility
        const shadowMetadata = {
            ...originalMetadata,
            name: `Shadow: ${originalMetadata.name || 'Unnamed Asset'}`,
            description: `This is a Shadow Wrapper for ${leaseInfo.originalCollection} #${leaseInfo.originalTokenId}. ${originalMetadata.description || ''}`,
            attributes: [
                ...(originalMetadata.attributes || []),
                { trait_type: "OmniLease Type", value: "Shadow Wrapper" },
                { trait_type: "Lease Expiry", value: new Date(leaseInfo.expiry * 1000).toISOString() },
                { trait_type: "Original Collection", value: leaseInfo.originalCollection }
            ],
            external_url: `https://omnilease.protocol/view/${shadowAddress}/${tokenId}`,
            properties: {
                ...originalMetadata.properties,
                isShadow: true,
                originalAsset: {
                    address: leaseInfo.originalCollection,
                    tokenId: leaseInfo.originalTokenId
                }
            }
        };

        return res.json(shadowMetadata);
    } catch (error) {
        console.error(`Metadata Proxy Error [${shadowAddress}:${tokenId}]:`, error.message);
        return res.status(500).json({ 
            error: "Metadata resolution failed",
            message: error.message 
        });
    }
});

module.exports = router;