// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../core/OmniAccessControl.sol";

interface AggregatorV3Interface {
    function decimals() external view returns (uint8);
    function description() external view returns (string memory);
    function version() external view returns (uint256);
    function getRoundData(uint80 _roundId)
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

/**
 * @title PricingOracle
 * @dev Integrates Chainlink for floor prices and calculates lease costs.
 */
contract PricingOracle is OmniAccessControl {
    struct CollectionConfig {
        address chainlinkFeed;
        uint256 manualFloorPrice; // Fallback or if feed is null
        uint256 bpsPerSecond;     // Rental rate in basis points (1/10000) per second
        uint256 minPrice;         // Minimum rental fee
        uint256 heartbeat;        // Max age of price data in seconds
    }

    mapping(address => CollectionConfig) public configs;

    event ConfigUpdated(address indexed collection, address feed, uint256 bps);

    /**
     * @dev Sets configuration for a collection.
     */
    function setConfig(
        address _collection,
        address _feed,
        uint256 _manualPrice,
        uint256 _bps,
        uint256 _minPrice,
        uint256 _heartbeat
    ) external onlyRole(OPERATOR_ROLE) {
        configs[_collection] = CollectionConfig({
            chainlinkFeed: _feed,
            manualFloorPrice: _manualPrice,
            bpsPerSecond: _bps,
            minPrice: _minPrice,
            heartbeat: _heartbeat
        });
        emit ConfigUpdated(_collection, _feed, _bps);
    }

    /**
     * @dev Returns the current floor price for a collection.
     */
    function getFloorPrice(address _collection) public view returns (uint256) {
        CollectionConfig memory config = configs[_collection];
        if (config.chainlinkFeed != address(0)) {
            (
                ,
                int256 answer,
                ,
                uint256 updatedAt,
                
            ) = AggregatorV3Interface(config.chainlinkFeed).latestRoundData();
            
            require(answer > 0, "Oracle: Invalid price");
            require(block.timestamp - updatedAt <= config.heartbeat, "Oracle: Stale price");
            
            return uint256(answer);
        }
        return config.manualFloorPrice;
    }

    /**
     * @dev Calculates lease price: (Floor * BPS * Duration) / 10000.
     * Reordered to multiply before divide to prevent precision loss.
     */
    function getLeasePrice(address _collection, uint256 _duration) external view returns (uint256) {
        CollectionConfig memory config = configs[_collection];
        uint256 floor = getFloorPrice(_collection);
        
        // Calculation: (Floor * BPS * Duration) / 10000
        uint256 price = (floor * config.bpsPerSecond * _duration) / 10000;
        
        return price < config.minPrice ? config.minPrice : price;
    }
}