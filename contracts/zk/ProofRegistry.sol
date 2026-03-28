// SPDX-License-Identifier: MIT
pragma ^0.8.24;

import "../core/OmniAccessControl.sol";

/**
 * @title ProofRegistry
 * @dev Stores and validates ZK-proof results for NFT lease eligibility.
 * Prevents double-spending of proofs and ensures only authorized engines can consume them.
 */
contract ProofRegistry is OmniAccessControl {
    // Mapping of nullifier to usage status to prevent replay attacks
    mapping(bytes32 => bool) public nullifiers;
    
    // Mapping of user address to their current eligibility status
    mapping(address => bool) public isEligible;

    event ProofVerified(address indexed user, bytes32 indexed nullifier);
    event EligibilityConsumed(address indexed user);

    /**
     * @dev Registers a successful ZK proof.
     * @param user The address of the user who proved eligibility.
     * @param a Groth16 proof point A
     * @param b Groth16 proof point B
     * @param c Groth16 proof point C
     * @param input Public inputs: [reputationThreshold, balanceThreshold, identityCommitment]
     * Note: In a production environment, this calls the ZkVerifier.sol.
     */
    function registerProof(
        address user,
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[3] calldata input
    ) external {
        // Ensure the proof is valid (Mocking the verifier call for the MVP flow)
        // In production: require(verifier.verifyProof(a, b, c, input), "Invalid ZK Proof");
        require(a[0] != 0 && b[0][0] != 0 && c[0] != 0, "Empty proof points");
        
        // Generate a unique nullifier to prevent replay.
        // We combine the identityCommitment (input[2]) with the user's address 
        // and a secret salt or contract-specific context to prevent cross-contract replays.
        bytes32 nullifier = keccak256(abi.encodePacked(input[2], user, address(this)));
        
        require(!nullifiers[nullifier], "Proof already used");
        
        nullifiers[nullifier] = true;
        isEligible[user] = true;

        emit ProofVerified(user, nullifier);
    }

    /**
     * @dev Consumes the eligibility status. Only callable by authorized OmniLease modules.
     * @param user The address whose eligibility is being consumed.
     */
    function consumeEligibility(address user) external onlyOperator {
        require(isEligible[user], "User not eligible");
        isEligible[user] = false;
        emit EligibilityConsumed(user);
    }

    /**
     * @dev Check if a user is currently eligible to mint a Shadow NFT.
     */
    function checkEligibility(address user) external view returns (bool) {
        return isEligible[user];
    }
}