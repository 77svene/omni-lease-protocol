pragma circom 2.1.4;

include "../../node_modules/circomlib/circuits/poseidon.circom";
include "../../node_modules/circomlib/circuits/comparators.circom";

/**
 * MerkleProof: Verifies inclusion in a Merkle Tree of depth 'levels'.
 */
template MerkleProof(levels) {
    signal input leaf;
    signal input pathIndices[levels];
    signal input siblings[levels];
    signal output root;

    component hashers[levels];
    signal nodes[levels + 1];
    nodes[0] <== leaf;

    for (var i = 0; i < levels; i++) {
        hashers[i] = Poseidon(2);
        // pathIndices[i] == 0 => leaf is left, sibling is right
        // pathIndices[i] == 1 => leaf is right, sibling is left
        signal left <== nodes[i] + pathIndices[i] * (siblings[i] - nodes[i]);
        signal right <== siblings[i] + pathIndices[i] * (nodes[i] - siblings[i]);
        
        hashers[i].inputs[0] <== left;
        hashers[i].inputs[1] <== right;
        nodes[i+1] <== hashers[i].out;
    }

    root <== nodes[levels];
}

/**
 * UtilityProof: Proves valid, non-expired utility access.
 * Public Inputs: collectionId, currentTime, leaseRoot
 * Private Inputs: walletSecret, tokenId, expiry, pathIndices, siblings
 */
template UtilityProof(levels) {
    // Public
    signal input collectionId;
    signal input currentTime;
    signal input leaseRoot;

    // Private
    signal input walletSecret;
    signal input tokenId;
    signal input expiry;
    signal input pathIndices[levels];
    signal input siblings[levels];

    // 1. Derive Identity (Commitment)
    component idHasher = Poseidon(1);
    idHasher.inputs[0] <== walletSecret;
    signal walletPubKey <== idHasher.out;

    // 2. Construct Leaf: Hash(walletPubKey, tokenId, expiry, collectionId)
    // This ensures the proof is bound to a specific collection and token.
    component leafHasher = Poseidon(4);
    leafHasher.inputs[0] <== walletPubKey;
    leafHasher.inputs[1] <== tokenId;
    leafHasher.inputs[2] <== expiry;
    leafHasher.inputs[3] <== collectionId;
    signal leaf <== leafHasher.out;

    // 3. Verify Merkle Inclusion
    component mp = MerkleProof(levels);
    mp.leaf <== leaf;
    for (var i = 0; i < levels; i++) {
        mp.pathIndices[i] <== pathIndices[i];
        mp.siblings[i] <== siblings[i];
    }
    
    // Constraint: Calculated root must match public leaseRoot
    mp.root === leaseRoot;

    // 4. Verify Expiry: currentTime < expiry
    component expiryCheck = LessThan(64);
    expiryCheck.in[0] <== currentTime;
    expiryCheck.in[1] <== expiry;
    
    // Constraint: Must not be expired
    expiryCheck.out === 1;
}

// Depth 4 allows for 16 concurrent leases per vault in this MVP
component main { public [collectionId, currentTime, leaseRoot] } = UtilityProof(4);