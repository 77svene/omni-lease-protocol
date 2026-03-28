/**
 * OmniLease Indexer Database Schema
 * Simple in-memory store for MVP. In production, this would be MongoDB or PostgreSQL.
 */

const db = {
  // Key: collectionAddress-tokenId
  assets: new Map(),
  
  // Key: userAddress -> Array of asset keys
  userLeases: new Map(),

  // Global stats
  stats: {
    totalLeased: 0,
    activeRentals: 0,
    totalVolumeUSDC: 0
  },

  /**
   * Update or create an asset record
   */
  upsertAsset(collection, tokenId, data) {
    const key = `${collection.toLowerCase()}-${tokenId}`;
    const existing = this.assets.get(key) || {};
    this.assets.set(key, { ...existing, ...data, lastUpdated: Date.now() });
  },

  /**
   * Mark an asset as rented
   */
  rentAsset(collection, tokenId, lessee, expiry, price) {
    const key = `${collection.toLowerCase()}-${tokenId}`;
    this.upsertAsset(collection, tokenId, {
      status: 'RENTED',
      lessee: lessee.toLowerCase(),
      expiry: Number(expiry),
      price: price.toString()
    });

    const userKey = lessee.toLowerCase();
    const currentLeases = this.userLeases.get(userKey) || [];
    if (!currentLeases.includes(key)) {
      currentLeases.push(key);
      this.userLeases.set(userKey, currentLeases);
    }
    
    this.stats.activeRentals++;
    this.stats.totalVolumeUSDC += Number(price) / 1e6; // Assuming 6 decimals for USDC
  },

  /**
   * Return asset to available pool
   */
  releaseAsset(collection, tokenId) {
    const key = `${collection.toLowerCase()}-${tokenId}`;
    const asset = this.assets.get(key);
    if (asset && asset.lessee) {
      const userKey = asset.lessee.toLowerCase();
      const currentLeases = this.userLeases.get(userKey) || [];
      this.userLeases.set(userKey, currentLeases.filter(k => k !== key));
      this.stats.activeRentals--;
    }
    this.upsertAsset(collection, tokenId, {
      status: 'AVAILABLE',
      lessee: null,
      expiry: 0
    });
  },

  /**
   * Query helper
   */
  getAvailable() {
    return Array.from(this.assets.values()).filter(a => a.status === 'AVAILABLE');
  }
};

module.exports = db;