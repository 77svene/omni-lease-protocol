const fs = require('fs');
const path = require('path');

/**
 * OmniLease Indexer Sync Status Manager
 * Tracks the last processed block height to ensure data consistency
 * and prevent duplicate event processing on restarts.
 */
class SyncStatus {
    constructor(filePath = 'sync-state.json') {
        this.statusPath = path.join(__dirname, filePath);
        this.state = {
            lastBlock: 0,
            lastSyncTimestamp: 0,
            isHealthy: true,
            errorCount: 0
        };
        this.load();
    }

    /**
     * Loads the sync state from the local filesystem.
     */
    load() {
        try {
            if (fs.existsSync(this.statusPath)) {
                const data = fs.readFileSync(this.statusPath, 'utf8');
                this.state = { ...this.state, ...JSON.parse(data) };
            }
        } catch (err) {
            console.error('[SyncStatus] Failed to load sync state:', err.message);
        }
    }

    /**
     * Persists the current sync state to the local filesystem.
     */
    save() {
        try {
            this.state.lastSyncTimestamp = Math.floor(Date.now() / 1000);
            fs.writeFileSync(this.statusPath, JSON.stringify(this.state, null, 2));
        } catch (err) {
            console.error('[SyncStatus] Failed to save sync state:', err.message);
        }
    }

    /**
     * Updates the last processed block number.
     * @param {number} blockNumber 
     */
    updateBlock(blockNumber) {
        if (blockNumber > this.state.lastBlock) {
            this.state.lastBlock = blockNumber;
            this.state.isHealthy = true;
            this.state.errorCount = 0;
            this.save();
        }
    }

    /**
     * Records an error and updates health status.
     */
    reportError() {
        this.state.errorCount++;
        if (this.state.errorCount > 5) {
            this.state.isHealthy = false;
        }
        this.save();
    }

    /**
     * Returns the block number where the indexer should start.
     * @param {number} defaultStartBlock 
     */
    getStartBlock(defaultStartBlock) {
        return this.state.lastBlock > 0 ? this.state.lastBlock + 1 : defaultStartBlock;
    }

    /**
     * Returns a health report for the API /health endpoint.
     */
    getHealthReport() {
        return {
            ...this.state,
            uptime: process.uptime(),
            nodeVersion: process.version
        };
    }
}

module.exports = new SyncStatus();