// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title UtilityToken
 * @dev Minimal ERC-1155-like implementation for time-bound utility rights.
 * Decouples usage from ownership. Minted by BaseLeaseVault.
 */
contract UtilityToken {
    string public name = "OmniLease Utility Token";
    string public symbol = "uwNFT";

    // tokenId => account => balance
    mapping(uint256 => mapping(address => uint256)) private _balances;
    // tokenId => expiry timestamp
    mapping(uint256 => uint256) public expiry;
    // tokenId => original NFT contract
    mapping(uint256 => address) public collection;
    // tokenId => original NFT tokenId
    mapping(uint256 => uint256) public underlyingId;

    address public minter;

    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event PermanentURI(string _value, uint256 indexed _id);

    constructor() {
        minter = msg.sender;
    }

    modifier onlyMinter() {
        require(msg.sender == minter, "UtilityToken: caller is not minter");
        _;
    }

    function mint(
        address to,
        uint256 id,
        uint256 _expiry,
        address _collection,
        uint256 _underlyingId
    ) external onlyMinter {
        require(to != address(0), "UtilityToken: mint to zero");
        _balances[id][to] = 1;
        expiry[id] = _expiry;
        collection[id] = _collection;
        underlyingId[id] = _underlyingId;

        emit TransferSingle(msg.sender, address(0), to, id, 1);
    }

    function burn(address from, uint256 id) external onlyMinter {
        require(_balances[id][from] > 0, "UtilityToken: insufficient balance");
        _balances[id][from] = 0;
        emit TransferSingle(msg.sender, from, address(0), id, 1);
    }

    function balanceOf(address account, uint256 id) public view returns (uint256) {
        if (block.timestamp > expiry[id]) return 0;
        return _balances[id][account];
    }

    function isExpired(uint256 id) public view returns (bool) {
        return block.timestamp > expiry[id];
    }

    function uri(uint256 id) public pure returns (string memory) {
        return "https://api.omnilease.xyz/utility/{id}";
    }
}