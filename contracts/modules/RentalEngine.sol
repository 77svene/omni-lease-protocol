// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../core/OmniAccessControl.sol";

/**
 * @title RentalEngine
 * @dev Calculates dynamic pricing for NFT rentals based on utilization and demand curves.
 */
contract RentalEngine is OmniAccessControl {
    struct PricingConfig {
        uint256 basePrice;      // Price at 0% utilization (wei per second)
        uint256 slope;          // Price increase per utilization point
        uint256 maxPrice;       // Hard cap on price
    }

    // collection => config
    mapping(address => PricingConfig) public collectionConfigs;
    // collection => activeLeases
    mapping(address => uint256) public activeLeases;
    // collection => totalInventory
    mapping(address => uint256) public totalInventory;

    event ConfigUpdated(address indexed collection, uint256 basePrice, uint256 slope, uint256 maxPrice);
    event InventoryUpdated(address indexed collection, uint256 totalInventory);

    /**
     * @dev Sets the pricing parameters for a specific NFT collection.
     */
    function setPricingConfig(
        address _collection,
        uint256 _basePrice,
        uint256 _slope,
        uint256 _maxPrice
    ) external onlyRole(OPERATOR_ROLE) {
        require(_collection != address(0), "RentalEngine: zero address");
        collectionConfigs[_collection] = PricingConfig({
            basePrice: _basePrice,
            slope: _slope,
            maxPrice: _maxPrice
        });
        emit ConfigUpdated(_collection, _basePrice, _slope, _maxPrice);
    }

    /**
     * @dev Updates inventory count for a collection. Called by Vaults on deposit/withdraw.
     */
    function updateInventory(address _collection, uint256 _total) external onlyRole(OPERATOR_ROLE) {
        totalInventory[_collection] = _total;
        emit InventoryUpdated(_collection, _total);
    }

    /**
     * @dev Tracks active lease count.
     */
    function updateActiveLeases(address _collection, bool _increment) external onlyRole(OPERATOR_ROLE) {
        if (_increment) {
            activeLeases[_collection]++;
        } else {
            require(activeLeases[_collection] > 0, "RentalEngine: underflow");
            activeLeases[_collection]--;
        }
    }

    /**
     * @dev Calculates the current price per second for a collection.
     * Formula: Price = Base + (Slope * (Active / Total))
     */
    function getPricePerSecond(address _collection) public view returns (uint256) {
        PricingConfig memory config = collectionConfigs[_collection];
        uint256 total = totalInventory[_collection];
        
        if (total == 0 || config.basePrice == 0) return config.basePrice;
        
        uint256 utilization = (activeLeases[_collection] * 1e18) / total;
        uint256 variablePrice = (config.slope * utilization) / 1e18;
        uint256 totalPrice = config.basePrice + variablePrice;
        
        return totalPrice > config.maxPrice ? config.maxPrice : totalPrice;
    }

    /**
     * @dev Estimates total cost for a duration.
     */
    function calculateRentalCost(address _collection, uint256 _duration) external view returns (uint256) {
        return getPricePerSecond(_collection) * _duration;
    }
}