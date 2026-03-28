pragma circom 2.1.4;

include "../../node_modules/circomlib/circuits/poseidon.circom";
include "../../node_modules/circomlib/circuits/comparators.circom";

/**
 * OmniLease: Lease Verification Circuit
 * Proves: 
 * 1. User knows a secret (privateKey) that corresponds to a public address (walletPubKey).
 * 2. User holds a lease for a specific collection.
 * 3. The lease has not expired (currentTime < expiry).
 * Hides: walletPubKey, tokenId.
 */
template LeaseVerify() {
    // Public Inputs
    signal input collectionId;      // Hash of the NFT collection address
    signal input currentTime;       // Current block timestamp
    signal input leaseRoot;         // Merkle root or state commitment of active leases

    // Private Inputs
    signal input tokenId;           // The specific NFT ID being leased
    signal input expiry;            // Expiration timestamp of the lease
    signal input walletSecret;      // Private key / secret of the lessee
    signal input salt;              // Randomness to prevent brute forcing

    // 1. Verify Expiry: currentTime < expiry
    component lt = LessThan(64);
    lt.in[0] <== currentTime;
    lt.in[1] <== expiry;
    lt.out === 1;

    // 2. Derive Wallet Public Identity (Simplified for MVP: Hash of secret)
    component pubKeyHasher = Poseidon(1);
    pubKeyHasher.inputs[0] <== walletSecret;
    signal walletPubKey <== pubKeyHasher.out;

    // 3. Generate Lease Commitment
    // This commitment must match what is stored in the LeaseRegistry/Vault
    // commitment = H(collectionId, tokenId, walletPubKey, expiry, salt)
    component leaseHasher = Poseidon(5);
    leaseHasher.inputs[0] <== collectionId;
    leaseHasher.inputs[1] <== tokenId;
    leaseHasher.inputs[2] <== walletPubKey;
    leaseHasher.inputs[3] <== expiry;
    leaseHasher.inputs[4] <== salt;

    // 4. Verify against public root
    // In a full production system, this would be a Merkle Proof check.
    // For the MVP, we prove the leaseHasher output matches the leaseRoot.
    leaseHasher.out === leaseRoot;
}

component main {public [collectionId, currentTime, leaseRoot]} = LeaseVerify();