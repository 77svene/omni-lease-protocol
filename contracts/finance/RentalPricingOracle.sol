// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../core/OmniAccess.sol";

/**
 * @title RentalPricingOracle
 * @dev Pulls floor prices and calculates suggested rental rates based on volatility and duration.
 * In a production environment, this would integrate with Chainlink or Reservoir.
 * For the MVP, it provides a managed price feed for the protocol.
 */
contract RentalPricingOracle is OmniAccess {
    struct PriceData {
        uint256 floorPrice; // in Wei
        uint256 lastUpdated;
        uint256 dailyRentalRateBps; // Basis points of floor price per day
    }

    // Collection address => PriceData
    mapping(address => PriceData) public collectionPrices;
    
    // Default rental rate: 0.1% of floor price per day (10 bps)
    uint256 public defaultDailyRateBps = 10;

    event PriceUpdated(address indexed collection, uint256 floorPrice, uint256 dailyRateBps);

    /**
     * @dev Updates the floor price and rental rate for a collection.
     * Only callable by authorized operators (e.g., a backend bot pulling from OpenSea/Blur).
     */
    function updatePrice(
        address _collection, 
        uint256 _floorPrice, 
        uint256 _dailyRateBps
    ) external onlyOperator {
        require(_collection != address(0), "Oracle: zero address");
        require(_floorPrice > 0, "Oracle: price must be > 0");

        collectionPrices[_collection] = PriceData({
            floorPrice: _floorPrice,
            lastUpdated: block.timestamp,
            dailyRentalRateBps: _dailyRateBps > 0 ? _dailyRateBps : defaultDailyRateBps
        });

        emit PriceUpdated(_collection, _floorPrice, _dailyRateBps);
    }

    /**
     * @dev Calculates the suggested rental price for a specific duration.
     * @param _collection The NFT collection address.
     * @param _duration The rental duration in seconds.
     * @return suggestedPrice The total price in Wei.
     */
    function getSuggestedPrice(address _collection, uint256 _duration) external view returns (uint256) {
        PriceData memory data = collectionPrices[_collection];
        require(data.floorPrice > 0, "Oracle: no price data");

        // (Floor Price * Daily Rate Bps * Duration) / (10000 bps * 1 day in seconds)
        uint256 price = (data.floorPrice * data.dailyRentalRateBps * _duration) / (10000 * 1 days);
        return price > 0 ? price : 1 gwei; // Minimum floor to prevent free rentals
    }

    function setDefaultDailyRate(uint256 _newRate) external onlyAdmin {
        defaultDailyRateBps = _newRate;
    }
}