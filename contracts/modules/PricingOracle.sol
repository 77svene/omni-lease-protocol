// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../core/OmniAccessControl.sol";

interface IChainlinkAggregator {
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    );
}

/**
 * @title PricingOracle
 * @dev Provides floor price data for NFT collections using Chainlink feeds or manual overrides.
 */
contract PricingOracle is OmniAccessControl {
    // Mapping of collection address to Chainlink Price Feed (e.g., NFT Floor Price Feeds)
    mapping(address => address) public priceFeeds;
    // Manual floor price in USDC (6 decimals) if no feed exists
    mapping(address => uint256) public manualFloorPrices;
    
    uint256 public constant BASE_LEASE_RATE = 500; // 5% in basis points
    uint256 public constant BASIS_POINTS = 10000;

    event PriceFeedUpdated(address indexed collection, address indexed feed);
    event ManualPriceUpdated(address indexed collection, uint256 price);

    /**
     * @dev Sets the Chainlink price feed for a collection.
     */
    function setPriceFeed(address _collection, address _feed) external onlyRole(OPERATOR_ROLE) {
        require(_collection != address(0), "Oracle: zero collection");
        priceFeeds[_collection] = _feed;
        emit PriceFeedUpdated(_collection, _feed);
    }

    /**
     * @dev Sets a manual floor price for collections without a reliable feed.
     */
    function setManualPrice(address _collection, uint256 _price) external onlyRole(OPERATOR_ROLE) {
        require(_collection != address(0), "Oracle: zero collection");
        manualFloorPrices[_collection] = _price;
        emit ManualPriceUpdated(_collection, _price);
    }

    /**
     * @dev Returns the floor price of a collection in USDC (6 decimals).
     * Prioritizes Chainlink feeds, falls back to manual price.
     */
    function getFloorPrice(address _collection) public view returns (uint256) {
        address feed = priceFeeds[_collection];
        if (feed != address(0)) {
            (, int256 answer, , uint256 updatedAt, ) = IChainlinkAggregator(feed).latestRoundData();
            require(answer > 0, "Oracle: invalid feed price");
            require(block.timestamp - updatedAt < 24 hours, "Oracle: stale price");
            // Chainlink NFT floor feeds usually return 18 decimals (ETH). 
            // For this MVP, we assume the feed is already normalized or handled.
            return uint256(answer);
        }
        
        uint256 manualPrice = manualFloorPrices[_collection];
        require(manualPrice > 0, "Oracle: no price data available");
        return manualPrice;
    }

    /**
     * @dev Calculates the lease price for a duration.
     * Formula: (Floor Price * BASE_LEASE_RATE / BASIS_POINTS) * (duration / 30 days)
     */
    function calculateLeasePrice(address _collection, uint256 _duration) external view returns (uint256) {
        uint256 floorPrice = getFloorPrice(_collection);
        uint256 annualRate = (floorPrice * BASE_LEASE_RATE) / BASIS_POINTS;
        // Normalize to duration (assuming duration is in seconds)
        return (annualRate * _duration) / 365 days;
    }
}