const snarkjs = require("snarkjs");
const fs = require("fs");
const path = require("path");

/**
 * OmniLease Proof Generator
 * Generates ZK-proofs for lease utility without revealing TokenID or Identity.
 */
class ProofGenerator {
    constructor() {
        this.wasmPath = path.join(__dirname, "../../circuits/lease_verify/leaseProof_js/leaseProof.wasm");
        this.zkeyPath = path.join(__dirname, "../../circuits/lease_verify/leaseProof_final.zkey");
    }

    /**
     * Generates a Groth16 proof for a lease.
     * @param {Object} inputs - The circuit inputs (collectionId, currentTime, leaseRoot, etc.)
     * @returns {Promise<Object>} - The proof and public signals.
     */
    async generateLeaseProof(inputs) {
        try {
            // In a real MVP environment, these files must exist from the 'circom' build step.
            if (!fs.existsSync(this.wasmPath) || !fs.existsSync(this.zkeyPath)) {
                // Fallback for dev/test if circuits aren't compiled yet
                console.warn("Circuit artifacts missing. Ensure 'snarkjs groth16 setup' was run.");
                throw new Error("ZK_ARTIFACTS_MISSING");
            }

            const { proof, publicSignals } = await snarkjs.groth16.fullProve(
                inputs,
                this.wasmPath,
                this.zkeyPath
            );

            return {
                proof,
                publicSignals,
                // Format for Solidity Verifier.sol
                solidityProof: this.formatForSolidity(proof, publicSignals)
            };
        } catch (error) {
            console.error("Proof Generation Failed:", error);
            throw error;
        }
    }

    /**
     * Formats the snarkjs proof into the [a, b, c] format expected by Verifier.sol
     */
    formatForSolidity(proof, publicSignals) {
        return {
            a: [proof.pi_a[0], proof.pi_a[1]],
            b: [
                [proof.pi_b[0][1], proof.pi_b[0][0]],
                [proof.pi_b[1][1], proof.pi_b[1][0]]
            ],
            c: [proof.pi_c[0], proof.pi_c[1]],
            inputs: publicSignals
        };
    }

    /**
     * Mock generator for testing when snarkjs environment is not fully provisioned
     */
    async generateMockProof(inputs) {
        console.log("Generating Mock Proof for inputs:", inputs.collectionId);
        return {
            proof: { pi_a: ["0", "0"], pi_b: [["0", "0"], ["0", "0"]], pi_c: ["0", "0"] },
            publicSignals: [inputs.collectionId, inputs.currentTime, inputs.leaseRoot],
            mock: true
        };
    }
}

module.exports = new ProofGenerator();