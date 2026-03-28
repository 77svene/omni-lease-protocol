// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./OmniAccess.sol";

interface IShadowNFT {
    function mint(address to, uint256 tokenId, string calldata uri) external;
    function burn(uint256 tokenId) external;
}

contract ShadowNFT is OmniAccess {
    string public name;
    string public symbol;
    mapping(uint256 => address) private _owners;
    mapping(uint256 => string) private _tokenURIs;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function mint(address to, uint256 tokenId, string calldata uri) external onlyOperator {
        require(to != address(0), "Shadow: zero address");
        require(_owners[tokenId] == address(0), "Shadow: exists");
        _owners[tokenId] = to;
        _tokenURIs[tokenId] = uri;
        emit Transfer(address(0), to, tokenId);
    }

    function burn(uint256 tokenId) external onlyOperator {
        address owner = _owners[tokenId];
        require(owner != address(0), "Shadow: not minted");
        delete _owners[tokenId];
        delete _tokenURIs[tokenId];
        emit Transfer(owner, address(0), tokenId);
    }

    function ownerOf(uint256 tokenId) external view returns (address) {
        return _owners[tokenId];
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        return _tokenURIs[tokenId];
    }
}

contract ShadowFactory is OmniAccess {
    mapping(address => address) public collectionToShadow;

    event ShadowCreated(address indexed original, address indexed shadow);

    function createShadow(address original, string calldata name, string calldata symbol) external onlyOperator returns (address shadow) {
        require(collectionToShadow[original] == address(0), "Factory: shadow exists");
        ShadowNFT newShadow = new ShadowNFT(name, symbol);
        newShadow.setOperator(msg.sender, true);
        shadow = address(newShadow);
        collectionToShadow[original] = shadow;
        emit ShadowCreated(original, shadow);
    }

    function mintShadow(address original, address to, uint256 tokenId, string calldata uri) external onlyOperator {
        address shadow = collectionToShadow[original];
        require(shadow != address(0), "Factory: no shadow contract");
        IShadowNFT(shadow).mint(to, tokenId, uri);
    }

    function burnShadow(address original, uint256 tokenId) external onlyOperator {
        address shadow = collectionToShadow[original];
        require(shadow != address(0), "Factory: no shadow contract");
        IShadowNFT(shadow).burn(tokenId);
    }
}