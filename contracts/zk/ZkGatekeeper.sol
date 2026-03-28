// SPDX-License-Identifier: MIT
pragma pragma ^0.8.24;

import "../core/OmniAccessControl.sol";

interface IVerifier {
    function verifyProof(
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory c,
        uint256[3] memory input
    ) external view returns (bool);
}

/**
 * @title ZkGatekeeper
 * @dev Authorizes access to dApp features based on ZK-proofs of valid NFT leases.
 * This contract acts as the middleware between the ZK Verifier and the dApp logic.
 */
contract ZkGatekeeper is OmniAccessControl {
    IVerifier public immutable verifier;
    
    // Mapping of collection hash to its current valid Merkle Root of leases
    mapping(bytes32 => uint256) public collectionLeaseRoots;
    
    // Prevent replay attacks by tracking used nullifiers (identity commitments)
    mapping(uint256 => bool) public usedNullifiers;

    event RootUpdated(bytes32 indexed collectionHash, uint256 newRoot);
    event AccessGranted(address indexed user, bytes32 indexed collectionHash);

    constructor(address _verifier) {
        require(_verifier != address(0), "Invalid verifier address");
        verifier = IVerifier(_verifier);
    }

    /**
     * @notice Updates the Merkle Root for a specific NFT collection.
     * @dev Only admins can update roots (usually synced from LeaseRegistry).
     */
    function updateLeaseRoot(bytes32 _collectionHash, uint256 _newRoot) external onlyAdmin {
        require(_newRoot != 0, "Root cannot be zero");
        collectionLeaseRoots[_collectionHash] = _newRoot;
        emit RootUpdated(_collectionHash, _newRoot);
    }

    /**
     * @notice Authorizes a user based on a ZK-proof.
     * @param a Groth16 proof part A
     * @param b Groth16 proof part B
     * @param c Groth16 proof part C
     * @param input Public inputs: [collectionId, currentTime, leaseRoot]
     * @param nullifier The identity commitment to prevent double-spending/replay in the same window
     */
    function authorize(
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory c,
        uint256[3] memory input,
        uint256 nullifier
    ) external returns (bool) {
        // 1. Verify the proof against the Verifier contract
        bool success = verifier.verifyProof(a, b, c, input);
        require(success, "Invalid ZK proof");

        // 2. Validate the public inputs
        bytes32 collectionHash = bytes32(input[0]);
        uint256 proofRoot = input[2];
        uint256 currentTime = input[1];

        require(collectionLeaseRoots[collectionHash] == proofRoot, "Stale or invalid lease root");
        require(currentTime <= block.timestamp, "Proof from the future");
        require(currentTime > block.timestamp - 1 hours, "Proof expired");
        
        // 3. Check nullifier to prevent replay
        require(!usedNullifiers[nullifier], "Nullifier already used");
        usedNullifiers[nullifier] = true;

        emit AccessGranted(msg.sender, collectionHash);
        return true;
    }

    /**
     * @notice Helper to hash collection addresses for the circuit
     */
    function getCollectionHash(address _collection) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_collection));
    }
}