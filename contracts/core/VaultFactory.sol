// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./VaultStorage.sol";
import "./OmniAccessControl.sol";

interface ILeaseRegistry {
    function registerVault(address _vault, address _collection) external;
}

contract VaultFactory is OmniAccessControl {
    address public immutable registry;
    mapping(address => address) public collectionToVault;
    address[] public allVaults;

    event VaultCreated(address indexed collection, address indexed vault);

    constructor(address _registry) {
        require(_registry != address(0), "Factory: zero registry");
        registry = _registry;
    }

    /**
     * @dev Deploys a new VaultStorage for a specific NFT collection.
     * The factory must have OPERATOR_ROLE in the Registry to succeed.
     */
    function createVault(address collection) external onlyRole(OPERATOR_ROLE) returns (address vault) {
        require(collection != address(0), "Factory: zero collection");
        require(collectionToVault[collection] == address(0), "Factory: vault exists");

        VaultStorage newVault = new VaultStorage(collection, msg.sender);
        vault = address(newVault);
        
        collectionToVault[collection] = vault;
        allVaults.push(vault);

        ILeaseRegistry(registry).registerVault(vault, collection);

        emit VaultCreated(collection, vault);
    }

    function getVaultCount() external view returns (uint256) {
        return allVaults.length;
    }
}