const express = require('express');
const { getLeaseStatus, getOriginalMetadata } = require('./leaseManager');
const { proxyMetadata } = require('./metadataRouter');

/**
 * OmniLease API Server
 * Provides real-time metadata resolution for Shadow NFTs.
 * Ensures that utility-bearing 'Shadow' tokens reflect the original asset's traits.
 */
const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

// Health Check
app.get('/health', (req, res) => {
    res.status(200).json({ status: 'active', protocol: 'OmniLease', version: '1.0.0' });
});

/**
 * Shadow NFT Metadata Endpoint
 * @param {string} shadowAddress - The address of the Shadow NFT contract
 * @param {string} tokenId - The specific token ID being queried
 * 
 * Flow:
 * 1. Verify the lease is active via LeaseRegistry (simulated in leaseManager)
 * 2. Fetch the original NFT's metadata URI from the SecureVault
 * 3. Merge original traits with Shadow-specific 'Lease' status
 */
app.get('/metadata/:shadowAddress/:tokenId', async (req, res) => {
    const { shadowAddress, tokenId } = req.params;

    try {
        // 1. Check if the lease is still valid
        const lease = await getLeaseStatus(shadowAddress, tokenId);
        
        if (!lease.active) {
            return res.status(403).json({ 
                error: 'Lease Expired', 
                message: 'This Shadow NFT no longer carries utility rights.' 
            });
        }

        // 2. Fetch original metadata
        const originalMetadata = await getOriginalMetadata(lease.originalCollection, lease.originalTokenId);

        // 3. Inject Shadow-specific attributes
        const shadowMetadata = {
            ...originalMetadata,
            name: `Shadow: ${originalMetadata.name || 'Unnamed NFT'}`,
            attributes: [
                ...(originalMetadata.attributes || []),
                { trait_type: 'OmniLease Status', value: 'Active Utility' },
                { trait_type: 'Lease Expiry', value: new Date(lease.expiry * 1000).toISOString() },
                { trait_type: 'Original Collection', value: lease.originalCollection }
            ],
            external_url: `https://omnilease.io/lease/${shadowAddress}/${tokenId}`
        };

        return res.json(shadowMetadata);
    } catch (error) {
        console.error('Metadata Error:', error.message);
        return res.status(500).json({ error: 'Internal Server Error', detail: error.message });
    }
});

/**
 * Direct Proxy for Images/Assets
 * Ensures games/marketplaces can load the original image through our gateway.
 */
app.get('/proxy/:cid', async (req, res) => {
    try {
        await proxyMetadata(req, res);
    } catch (error) {
        res.status(502).send('Gateway Error');
    }
});

const server = app.listen(PORT, () => {
    console.log(`OmniLease API running on port ${PORT}`);
    console.log(`Metadata Route: http://localhost:${PORT}/metadata/:shadowAddress/:tokenId`);
});

// Graceful shutdown for clean testing
process.on('SIGTERM', () => {
    server.close(() => {
        console.log('Process terminated');
    });
});

module.exports = app;