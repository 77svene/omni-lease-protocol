// SPDX-License-Identifier: MIT
pragma ^0.8.24;

/**
 * @title ProofRegistry
 * @dev Stores and validates nullifiers to prevent double-spending of ZK proofs.
 * This is a critical security component for the OmniLease 'Shadow Wrapper' architecture.
 */
contract ProofRegistry {
    // Mapping from nullifier (hash of user secret + action) to usage status
    mapping(bytes32 => bool) public usedNullifiers;
    
    // Mapping from proof hash to verification status
    mapping(bytes32 => bool) public verifiedProofs;

    event ProofRegistered(bytes32 indexed nullifier, address indexed submitter, uint256 timestamp);
    event ProofRevoked(bytes32 indexed nullifier, string reason);

    error NullifierAlreadyUsed();
    error InvalidProofHash();
    error UnauthorizedCaller();

    address public immutable factory;

    constructor(address _factory) {
        require(_factory != address(0), "Invalid factory address");
        factory = _factory;
    }

    /**
     * @notice Registers a nullifier to prevent replay attacks.
     * @param _nullifier The unique identifier derived from the ZK proof.
     * @param _proofHash A hash of the full proof for auditing.
     */
    function registerProof(bytes32 _nullifier, bytes32 _proofHash) external {
        // Only the ShadowFactory or RentalEngine should typically call this
        if (msg.sender != factory) revert UnauthorizedCaller();
        if (usedNullifiers[_nullifier]) revert NullifierAlreadyUsed();
        if (_proofHash == bytes32(0)) revert InvalidProofHash();

        usedNullifiers[_nullifier] = true;
        verifiedProofs[_proofHash] = true;

        emit ProofRegistered(_nullifier, tx.origin, block.timestamp);
    }

    /**
     * @notice Checks if a nullifier has already been consumed.
     * @param _nullifier The nullifier to check.
     * @return bool True if the nullifier is spent.
     */
    function isSpent(bytes32 _nullifier) external view returns (bool) {
        return usedNullifiers[_nullifier];
    }

    /**
     * @notice Verifies if a specific proof hash was previously registered.
     * @param _proofHash The hash of the proof.
     */
    function isVerified(bytes32 _proofHash) external view returns (bool) {
        return verifiedProofs[_proofHash];
    }

    /**
     * @notice Emergency revocation of a nullifier (e.g., if a proof was found to be malicious).
     * @dev In a production environment, this would be gated by a DAO or Multisig.
     */
    function revokeProof(bytes32 _nullifier, string calldata _reason) external {
        if (msg.sender != factory) revert UnauthorizedCaller();
        usedNullifiers[_nullifier] = false;
        emit ProofRevoked(_nullifier, _reason);
    }
}