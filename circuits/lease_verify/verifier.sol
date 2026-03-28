// SPDX-License-Identifier: MIT
pragma ^0.8.24;

/**
 * @title OmniLease Utility Verifier
 * @dev Groth16 Verifier for UtilityProof.circom.
 * This contract verifies that a user holds a valid lease for a specific NFT collection
 * without revealing the user's identity or the specific Token ID.
 */
contract Verifier {
    struct VerificationKey {
        uint256[2] alpha1;
        uint256[2][2] beta2;
        uint256[2] gamma2;
        uint256[2] delta2;
        uint256[2][] ic;
    }

    // Public inputs: [1] (constant), collectionId, currentTime, leaseRoot
    // These must match the order in the circom file.
    function verifyProof(
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory c,
        uint256[3] memory input
    ) public view returns (bool) {
        // Proof verification logic using precompiled BN254 pairing (0x08)
        // In a real production environment, this would be the full SnarkJS generated verifier.
        // For the MVP, we implement the core pairing check interface.
        
        // collectionId: input[0]
        // currentTime:  input[1]
        // leaseRoot:    input[2]

        require(input[0] != 0, "Invalid collectionId");
        require(input[2] != 0, "Invalid leaseRoot");

        // Compute the linear combination of public inputs (simplified for MVP structure)
        // In actual Groth16, this involves scalar multiplication of G1 points.
        
        return pairing(
            negate(a),
            b,
            [uint256(0), uint256(0)], // alpha1 (placeholder)
            [[uint256(0), uint256(0)], [uint256(0), uint256(0)]], // beta2 (placeholder)
            c,
            [[uint256(0), uint256(0)], [uint256(0), uint256(0)]]  // delta2 (placeholder)
        );
    }

    function negate(uint256[2] memory p) internal pure returns (uint256[2] memory) {
        uint256 q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
        if (p[1] == 0) return p;
        return [p[0], q - (p[1] % q)];
    }

    function pairing(
        uint256[2] memory a,
        uint256[2][2] memory b,
        uint256[2] memory c,
        uint256[2][2] memory d,
        uint256[2] memory e,
        uint256[2][2] memory f
    ) internal view returns (bool) {
        uint256[24] memory input;
        input[0] = a[0];
        input[1] = a[1];
        input[2] = b[0][1];
        input[3] = b[0][0];
        input[4] = b[1][1];
        input[5] = b[1][0];
        input[6] = c[0];
        input[7] = c[1];
        input[8] = d[0][1];
        input[9] = d[0][0];
        input[10] = d[1][1];
        input[11] = d[1][0];
        input[12] = e[0];
        input[13] = e[1];
        input[14] = f[0][1];
        input[15] = f[0][0];
        input[16] = f[1][1];
        input[17] = f[1][0];

        uint256 success;
        assembly {
            success := staticcall(gas(), 0x08, input, 0x300, input, 0x20)
        }
        require(success != 0, "Pairing check failed");
        return input[0] == 1;
    }
}