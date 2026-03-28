pragma circom 2.1.4;

include "../../node_modules/circomlib/circuits/poseidon.circom";
include "../../node_modules/circomlib/circuits/comparators.circom";

/**
 * OmniLease: Lease Verification Circuit
 * Proves: 
 * 1. User knows a secret (walletSecret) that derives their public identity.
 * 2. User holds a lease that is part of the Merkle Tree (leaseRoot).
 * 3. The lease has not expired (currentTime < expiry).
 * Hides: walletPubKey, tokenId, and specific leaf index.
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
        // If pathIndices[i] is 0, node is left, sibling is right
        // If pathIndices[i] is 1, node is right, sibling is left
        hashers[i].inputs[0] <== nodes[i] + pathIndices[i] * (siblings[i] - nodes[i]);
        hashers[i].inputs[1] <== siblings[i] + pathIndices[i] * (nodes[i] - siblings[i]);
        nodes[i+1] <== hashers[i].out;
    }

    root <== nodes[levels];
}

template LeaseVerify(levels) {
    // Public Inputs
    signal input collectionId;      // Hash of the NFT collection address
    signal input currentTime;       // Current block timestamp
    signal input leaseRoot;         // Merkle root of active leases

    // Private Inputs
    signal input tokenId;           
    signal input expiry;            
    signal input walletSecret;      
    signal input salt;              
    signal input pathIndices[levels];
    signal input siblings[levels];

    // 1. Verify Expiry: currentTime < expiry
    component lt = LessThan(64);
    lt.in[0] <== currentTime;
    lt.in[1] <== expiry;
    lt.out === 1;

    // 2. Derive Wallet Identity (Poseidon hash of secret)
    component pubKeyHasher = Poseidon(1);
    pubKeyHasher.inputs[0] <== walletSecret;
    signal walletPubKey <== pubKeyHasher.out;

    // 3. Generate Lease Leaf
    // leaf = H(collectionId, tokenId, walletPubKey, expiry, salt)
    component leafHasher = Poseidon(5);
    leafHasher.inputs[0] <== collectionId;
    leafHasher.inputs[1] <== tokenId;
    leafHasher.inputs[2] <== walletPubKey;
    leafHasher.inputs[3] <== expiry;
    leafHasher.inputs[4] <== salt;
    
    signal leaf <== leafHasher.out;

    // 4. Verify Merkle Membership
    component mp = MerkleProof(levels);
    mp.leaf <== leaf;
    for (var i = 0; i < levels; i++) {
        mp.pathIndices[i] <== pathIndices[i];
        mp.siblings[i] <== siblings[i];
    }

    // Ensure calculated root matches public leaseRoot
    mp.root === leaseRoot;
}

component main {public [collectionId, currentTime, leaseRoot]} = LeaseVerify(10);