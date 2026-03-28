// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./OmniAccessControl.sol";

/**
 * @title LeaseRegistry
 * @dev Tracks all active vaults and manages global permissions for the OmniLease protocol.
 */
contract LeaseRegistry is OmniAccessControl {
    struct LeaseInfo {
        address vault;
        address collection;
        bool isActive;
        uint256 createdAt;
    }

    // Mapping of vault address to its lease metadata
    mapping(address => LeaseInfo) public vaults;
    // Mapping of collection address to its designated vault
    mapping(address => address) public collectionToVault;
    
    address[] public allVaults;

    event VaultRegistered(address indexed vault, address indexed collection);
    event VaultStatusUpdated(address indexed vault, bool isActive);

    /**
     * @dev Registers a new vault for a specific NFT collection.
     * Only callable by accounts with OPERATOR_ROLE (e.g., the VaultFactory).
     */
    function registerVault(address _vault, address _collection) external onlyRole(OPERATOR_ROLE) {
        require(_vault != address(0), "Registry: zero vault address");
        require(_collection != address(0), "Registry: zero collection address");
        require(vaults[_vault].vault == address(0), "Registry: vault already registered");
        require(collectionToVault[_collection] == address(0), "Registry: collection already has vault");

        vaults[_vault] = LeaseInfo({
            vault: _vault,
            collection: _collection,
            isActive: true,
            createdAt: block.timestamp
        });

        collectionToVault[_collection] = _vault;
        allVaults.push(_vault);

        emit VaultRegistered(_vault, _collection);
    }

    function setVaultStatus(address _vault, bool _isActive) external onlyRole(OPERATOR_ROLE) {
        require(vaults[_vault].vault != address(0), "Registry: vault not found");
        vaults[_vault].isActive = _isActive;
        emit VaultStatusUpdated(_vault, _isActive);
    }

    function getVaultCount() external view returns (uint256) {
        return allVaults.length;
    }

    function isVaultActive(address _vault) external view returns (bool) {
        return vaults[_vault].isActive;
    }
}