// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../core/OmniAccessControl.sol";

/**
 * @title PricingOracle
 * @dev Integrates with Chainlink-style price feeds or manual floor price updates.
 * In a production environment, this would consume Chainlink NFT Floor Price Feeds.
 */
contract PricingOracle is OmniAccessControl {
    struct PriceData {
        uint256 floorPrice; // In Wei (or USDC equivalent)
        uint256 lastUpdated;
        bool exists;
    }

    // Collection address => PriceData
    mapping(address => PriceData) public collectionPrices;
    
    // Global multiplier for rental rates (e.g., 500 = 5% of floor price per day)
    // Basis points: 10000 = 100%
    uint256 public dailyRateBps = 100; // Default 1%

    event PriceUpdated(address indexed collection, uint256 floorPrice);
    event RateUpdated(uint256 newRateBps);

    /**
     * @dev Updates the floor price for a collection. 
     * In MVP, this is restricted to OPERATOR_ROLE (simulating an oracle relayer).
     */
    function updateFloorPrice(address _collection, uint256 _floorPrice) external onlyRole(OPERATOR_ROLE) {
        require(_collection != address(0), "Oracle: zero address");
        
        collectionPrices[_collection] = PriceData({
            floorPrice: _floorPrice,
            lastUpdated: block.timestamp,
            exists: true
        });

        emit PriceUpdated(_collection, _floorPrice);
    }

    /**
     * @dev Sets the global daily rental rate in basis points.
     */
    function setDailyRateBps(uint256 _bps) external onlyRole(ADMIN_ROLE) {
        require(_bps <= 10000, "Oracle: rate too high");
        dailyRateBps = _bps;
        emit RateUpdated(_bps);
    }

    /**
     * @dev Calculates the lease price for a duration.
     * @param _collection The NFT collection address.
     * @param _duration Duration in seconds.
     * @return totalCost The calculated cost in the same denomination as floorPrice.
     */
    function getLeasePrice(address _collection, uint256 _duration) external view returns (uint256 totalCost) {
        PriceData memory data = collectionPrices[_collection];
        require(data.exists, "Oracle: no price data");

        // (Floor Price * Daily Rate Bps / 10000) * (Duration / 1 Day)
        uint256 dailyCost = (data.floorPrice * dailyRateBps) / 10000;
        totalCost = (dailyCost * _duration) / 1 days;
        
        // Ensure a minimum price of 0.0001 units if floor price exists
        if (totalCost == 0 && data.floorPrice > 0) {
            totalCost = data.floorPrice / 10000; 
        }
    }

    /**
     * @dev Check if a collection has pricing data.
     */
    function isSupported(address _collection) external view returns (bool) {
        return collectionPrices[_collection].exists;
    }
}