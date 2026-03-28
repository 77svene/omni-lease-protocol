pragma circom 2.1.4;

include "../../node_modules/circomlib/circuits/poseidon.circom";
include "../../node_modules/circomlib/circuits/comparators.circom";

/**
 * OmniLease: Eligibility Circuit
 * Proves:
 * 1. User knows the secret to a public identity (nullifier derivation).
 * 2. User's reputation score is >= requiredThreshold.
 * 3. User's credit balance is >= requiredBalance.
 * Hides: userSecret, actual reputation, actual balance.
 */
template Eligibility() {
    // Public Inputs
    signal input reputationThreshold;
    signal input balanceThreshold;
    signal input identityCommitment; // Hash(userSecret)

    // Private Inputs
    signal input userSecret;
    signal input userReputation;
    signal input userBalance;

    // 1. Verify Identity Ownership
    component idHasher = Poseidon(1);
    idHasher.inputs[0] <== userSecret;
    idHasher.out === identityCommitment;

    // 2. Check Reputation >= Threshold
    component repCheck = GreaterEqThan(32); // 32-bit integer comparison
    repCheck.in[0] <== userReputation;
    repCheck.in[1] <== reputationThreshold;
    repCheck.out === 1;

    // 3. Check Balance >= Threshold
    component balCheck = GreaterEqThan(64); // 64-bit for larger balances
    balCheck.in[0] <== userBalance;
    balCheck.in[1] <== balanceThreshold;
    balCheck.out === 1;

    // Output a nullifier to prevent double-claiming/replay within a specific context
    // Nullifier = Hash(userSecret, "ELIGIBILITY_V1")
    component nullifierHasher = Poseidon(2);
    nullifierHasher.inputs[0] <== userSecret;
    nullifierHasher.inputs[1] <== 123456789; // Domain separator
    
    signal output nullifier;
    nullifier <== nullifierHasher.out;
}

component main { public [reputationThreshold, balanceThreshold, identityCommitment] } = Eligibility();