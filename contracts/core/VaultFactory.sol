// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./VaultStorage.sol";
import "./OmniAccessControl.sol";

contract VaultFactory is OmniAccessControl {
    mapping(address => address) public collectionToVault;
    address[] public allVaults;

    event VaultCreated(address indexed collection, address indexed vault);

    function createVault(address collection) external onlyRole(OPERATOR_ROLE) returns (address vault) {
        require(collection != address(0), "Factory: zero address");
        require(collectionToVault[collection] == address(0), "Factory: vault exists");

        VaultStorage newVault = new VaultStorage();
        
        // Set the factory (msg.sender) as the admin of the new vault
        // Then transfer admin to the protocol admin
        newVault.setOperator(msg.sender, true);
        
        vault = address(newVault);
        collectionToVault[collection] = vault;
        allVaults.push(vault);

        emit VaultCreated(collection, vault);
    }

    function getVaultCount() external view returns (uint256) {
        return allVaults.length;
    }
}