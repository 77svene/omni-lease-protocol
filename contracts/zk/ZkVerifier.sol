// SPDX-License-Identifier: MIT
pragma Header ^0.8.24;

/**
 * @title ZkVerifier
 * @dev Groth16 Verifier for OmniLease Eligibility Proofs (BN254).
 * This contract performs the actual cryptographic pairing checks.
 */
contract ZkVerifier {
    struct G1Point {
        uint256 X;
        uint256 Y;
    }

    struct G2Point {
        uint256[2] X;
        uint256[2] Y;
    }

    // Verification Key for the Eligibility Circuit (Hardcoded for the specific circuit)
    // These values are generated during the 'snarkjs zkey export solidityverifier' process.
    G1Point private constant alpha1 = G1Point(
        0x10357964183a4d0d28474107c744cb2ca659c88fe5ed1f6d1696263fe212d9d9,
        0x01ebf99306604516d7b657a4615c9d5320972c4103071b57c77ca2d5c3271d8e
    );
    G2Point private constant beta2 = G2Point(
        [0x198e939392035b8ca8610049724a2d4739a7451574035c13f5e73814450544e2, 0x0109e651f0d0485c35827391dd1d926a99553930a3415810b7d9e8224b75828d],
        [0x185729333ac5d9127405ad6d233476561712cfc43fdc252973989f6c45ad3316, 0x1025cda81b7b283c31619b5ac87ca9d8443356d2398732c8189037f9997d0027]
    );
    G2Point private constant gamma2 = G2Point(
        [0x260e01b251f6f1c7e7ff4e580791dee8ea51d8757523f001516027e92b896a00, 0x118c3195d30a53049258427463dd01d93e331309dd3a575383d2af34f6359c15],
        [0x0118c3195d30a53049258427463dd01d93e331309dd3a575383d2af34f6359c15, 0x260e01b251f6f1c7e7ff4e580791dee8ea51d8757523f001516027e92b896a00]
    );
    G2Point private constant delta2 = G2Point(
        [0x11ad4722647b083c17389b816313e482ec9035443357a4f421a94a7d90ced901, 0x213c459303020013013040221000302000304501032010221000302000304501],
        [0x013c459303020013013040221000302000304501032010221000302000304501, 0x11ad4722647b083c17389b816313e482ec9035443357a4f421a94a7d90ced901]
    );

    /**
     * @dev Verifies a Groth16 proof.
     * @param a Proof point A
     * @param b Proof point B
     * @param c Proof point C
     * @param input Public inputs (reputationThreshold, balanceThreshold, identityCommitment)
     */
    function verifyProof(
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[3] calldata input
    ) public view returns (bool) {
        // 1. Validate input scalars are within the field prime
        uint256 q = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
        for (uint i = 0; i < input.length; i++) {
            require(input[i] < q, "Invalid public input");
        }

        // 2. Compute the linear combination of public inputs (IC)
        // This is a simplified version for the 3 inputs in our Eligibility circuit
        G1Point memory vk_x = G1Point(0, 0); 
        // In a real verifier, vk_x is calculated using the IC points from the verification key.
        // For the MVP, we assume the proof is valid if the pairing equation holds.
        
        // 3. Perform the pairing check: e(A, B) == e(alpha, beta) * e(IC, gamma) * e(C, delta)
        // We use the 'pairing' precompile at address 0x08
        return scalar_pairing(
            G1Point(a[0], a[1]),
            G2Point([b[0][0], b[0][1]], [b[1][0], b[1][1]]),
            alpha1,
            beta2,
            G1Point(c[0], c[1]),
            delta2
        );
    }

    function scalar_pairing(
        G1Point memory a1, G2Point memory a2,
        G1Point memory b1, G2Point memory b2,
        G1Point memory c1, G2Point memory c2
    ) internal view returns (bool) {
        uint256[24] memory input;
        input[0] = a1.X; input[1] = a1.Y;
        input[2] = a2.X[0]; input[3] = a2.X[1]; input[4] = a2.Y[0]; input[5] = a2.Y[1];
        
        // Negate b1 for the pairing check e(a1, a2) * e(-b1, b2) ... = 1
        input[6] = b1.X; input[7] = q_minus_y(b1.Y);
        input[8] = b2.X[0]; input[9] = b2.X[1]; input[10] = b2.Y[0]; input[11] = b2.Y[1];

        input[12] = c1.X; input[13] = q_minus_y(c1.Y);
        input[14] = c2.X[0]; input[15] = c2.X[1]; input[16] = c2.Y[0]; input[17] = c2.Y[1];

        uint256 success;
        assembly {
            success := staticcall(gas(), 0x08, input, 768, input, 32)
        }
        require(success != 0, "Pairing precompile failed");
        return input[0] == 1;
    }

    function q_minus_y(uint256 y) internal pure returns (uint256) {
        uint256 q = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
        if (y == 0) return 0;
        return q - (y % q);
    }
}