// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../core/OmniAccessControl.sol";
import "./UtilityToken.sol";
import "./TimeLockLogic.sol";

interface IERC721 {
    function transferFrom(address from, address to, uint256 tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address);
}

/**
 * @title BaseLeaseVault
 * @dev Escrows NFTs and issues time-bound UtilityTokens (ERC1155).
 */
contract BaseLeaseVault is OmniAccessControl {
    address public immutable collection;
    UtilityToken public immutable utilityToken;
    
    struct Lease {
        address owner;
        uint256 tokenId;
        uint256 expiry;
        bool active;
    }

    // Mapping from NFT tokenId to its current Lease status
    mapping(uint256 => Lease) public leases;

    event NFTDeposited(address indexed owner, uint256 indexed tokenId, uint256 duration);
    event NFTRedeemed(address indexed owner, uint256 indexed tokenId);

    constructor(address _collection) {
        require(_collection != address(0), "Vault: zero collection");
        collection = _collection;
        utilityToken = new UtilityToken("OmniLease Utility", "uwNFT");
        // Grant this vault operator role on the utility token it just created
        utilityToken.grantRole(keccak256("OPERATOR_ROLE"), address(this));
    }

    /**
     * @dev Deposit an NFT to mint a utility token for a specific duration.
     * @param tokenId The NFT ID to lock.
     * @param duration Seconds the utility remains valid.
     */
    function deposit(uint256 tokenId, uint256 duration) external {
        require(duration > 0, "Vault: duration must be > 0");
        require(!leases[tokenId].active, "Vault: NFT already in vault");

        // Transfer NFT to vault
        IERC721(collection).transferFrom(msg.sender, address(this), tokenId);

        uint256 expiry = block.timestamp + duration;
        leases[tokenId] = Lease({
            owner: msg.sender,
            tokenId: tokenId,
            expiry: expiry,
            active: true
        });

        // Mint UtilityToken (ERC1155) to the owner
        // Token ID in ERC1155 matches the NFT Token ID
        utilityToken.mint(msg.sender, tokenId, 1, "");

        emit NFTDeposited(msg.sender, tokenId, duration);
    }

    /**
     * @dev Withdraw the NFT after the utility period has expired.
     * @param tokenId The NFT ID to reclaim.
     */
    function withdraw(uint256 tokenId) external {
        Lease storage lease = leases[tokenId];
        require(lease.active, "Vault: lease not active");
        require(msg.sender == lease.owner, "Vault: not owner");
        require(block.timestamp >= lease.expiry, "Vault: lease not expired");

        lease.active = false;
        
        // Burn the utility token (even if the owner transferred it, the utility is dead)
        // In a real production app, we'd handle the 1155 balance check or force burn
        // For MVP, we assume the owner holds the right to reclaim the physical asset
        
        IERC721(collection).transferFrom(address(this), msg.sender, tokenId);
        
        emit NFTRedeemed(msg.sender, tokenId);
    }

    /**
     * @dev Check if a specific NFT's utility is currently valid.
     */
    function isUtilityValid(uint256 tokenId) external view returns (bool) {
        Lease memory lease = leases[tokenId];
        return (lease.active && block.timestamp < lease.expiry);
    }
}