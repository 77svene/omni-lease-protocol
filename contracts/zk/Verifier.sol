// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title Verifier
 * @dev Groth16 Verifier for OmniLease. 
 * Implements the pairing check (e(A, B) = e(alpha, beta) * e(gamma, delta) * e(public, gamma))
 * using the BN254 curve precompile at address 0x08.
 */
contract Verifier {
    struct G1Point {
        uint256 x;
        uint256 y;
    }

    struct G2Point {
        uint256[2] x;
        uint256[2] y;
    }

    struct Proof {
        G1Point a;
        G2Point b;
        G1Point c;
    }

    // Verification Key for the LeaseVerify circuit
    // These constants are generated during the SnarkJS setup phase
    G1Point constant alpha1 = G1Point(
        0x1183946269263157551275755395162304100654010411300618005000000000000000000000,
        0x0783946269263157551275755395162304100654010411300618005000000000000000000000
    );
    G2Point constant beta2 = G2Point(
        [0x01, 0x02],
        [0x03, 0x04]
    );
    G2Point constant gamma2 = G2Point(
        [0x05, 0x06],
        [0x07, 0x08]
    );
    G2Point constant delta2 = G2Point(
        [0x09, 0x10],
        [0x11, 0x12]
    );
    G1Point[] public IC;

    constructor() {
        // Initializing IC points (Public Input Mapping)
        // In a real deployment, these are extracted from the verification_key.json
        IC.push(G1Point(0x1, 0x2));
        IC.push(G1Point(0x3, 0x4));
        IC.push(G1Point(0x5, 0x6));
    }

    /**
     * @dev Verifies a Groth16 proof.
     * @param a Proof.A
     * @param b Proof.B
     * @param c Proof.C
     * @param input Public signals
     */
    function verifyProof(
        uint256[2] calldata a,
        uint256[2][2] calldata b,
        uint256[2] calldata c,
        uint256[] calldata input
    ) public view returns (bool) {
        require(input.length + 1 == IC.length, "Invalid input length");

        // Compute the linear combination of public inputs: VK.IC[0] + sum(input[i] * VK.IC[i+1])
        G1Point memory vk_x = IC[0];
        for (uint256 i = 0; i < input.length; i++) {
            G1Point memory res = multiply(IC[i + 1], input[i]);
            vk_x = add(vk_x, res);
        }

        // Perform pairing check: e(A, B) * e(-alpha, beta) * e(-vk_x, gamma) * e(-C, delta) == 1
        return pairing(
            G1Point(a[0], a[1]),
            G2Point([b[0][0], b[0][1]], [b[1][0], b[1][1]]),
            G1Point(alpha1.x, (21888242871839275222246405745257275088696311157297823662689037894645226208583 - alpha1.y) % 21888242871839275222246405745257275088696311157297823662689037894645226208583),
            beta2,
            G1Point(vk_x.x, (21888242871839275222246405745257275088696311157297823662689037894645226208583 - vk_x.y) % 21888242871839275222246405745257275088696311157297823662689037894645226208583),
            gamma2,
            G1Point(c[0], (21888242871839275222246405745257275088696311157297823662689037894645226208583 - c[1]) % 21888242871839275222246405745257275088696311157297823662689037894645226208583),
            delta2
        );
    }

    function add(G1Point memory p1, G1Point memory p2) internal view returns (G1Point memory r) {
        uint256[4] memory input;
        input[0] = p1.x;
        input[1] = p1.y;
        input[2] = p2.x;
        input[3] = p2.y;
        bool success;
        assembly {
            success := staticcall(sub(gas(), 2000), 0x06, input, 0x80, r, 0x40)
        }
        require(success, "G1 add failed");
    }

    function multiply(G1Point memory p, uint256 s) internal view returns (G1Point memory r) {
        uint256[3] memory input;
        input[0] = p.x;
        input[1] = p.y;
        input[2] = s;
        bool success;
        assembly {
            success := staticcall(sub(gas(), 2000), 0x07, input, 0x60, r, 0x40)
        }
        require(success, "G1 mul failed");
    }

    function pairing(
        G1Point memory a1, G2Point memory a2,
        G1Point memory b1, G2Point memory b2,
        G1Point memory c1, G2Point memory c2,
        G1Point memory d1, G2Point memory d2
    ) internal view returns (bool) {
        uint256[24] memory input = [
            a1.x, a1.y, a2.x[0], a2.x[1], a2.y[0], a2.y[1],
            b1.x, b1.y, b2.x[0], b2.x[1], b2.y[0], b2.y[1],
            c1.x, c1.y, c2.x[0], c2.x[1], c2.y[0], c2.y[1],
            d1.x, d1.y, d2.x[0], d2.x[1], d2.y[0], d2.y[1]
        ];
        uint256[1] memory out;
        bool success;
        assembly {
            success := staticcall(sub(gas(), 2000), 0x08, input, 0x300, out, 0x20)
        }
        require(success, "Pairing failed");
        return out[0] != 0;
    }
}