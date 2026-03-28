// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./OmniAccess.sol";

interface IERC721 {
    function transferFrom(address from, address to, uint256 tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address);
}

contract VaultStorage is OmniAccess {
    // Mapping of asset address => tokenId => original owner
    mapping(address => mapping(uint256 => address)) public originalOwners;

    event Deposited(address indexed asset, uint256 indexed tokenId, address indexed owner);
    event Withdrawn(address indexed asset, uint256 indexed tokenId, address indexed owner);

    function deposit(address asset, uint256 tokenId, address owner) external onlyOperator {
        require(originalOwners[asset][tokenId] == address(0), "Vault: already deposited");
        originalOwners[asset][tokenId] = owner;
        IERC721(asset).transferFrom(owner, address(this), tokenId);
        emit Deposited(asset, tokenId, owner);
    }

    function withdraw(address asset, uint256 tokenId, address to) external onlyOperator {
        require(originalOwners[asset][tokenId] == to, "Vault: not the owner");
        delete originalOwners[asset][tokenId];
        IERC721(asset).transferFrom(address(this), to, tokenId);
        emit Withdrawn(asset, tokenId, to);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return 0x150b7a02; // IERC721Receiver.onERC721Received.selector
    }
}