const snarkjs = require("snarkjs");
const fs = require("fs");
const path = require("path");

/**
 * OmniLease ZK Prover
 * Generates a proof for the Eligibility circuit.
 * Requirements: 
 * 1. eligibility.wasm (compiled circuit)
 * 2. eligibility_final.zkey (trusted setup key)
 */
async function generateEligibilityProof(inputPath, wasmPath, zkeyPath) {
    try {
        // Read input signals from JSON
        const input = JSON.parse(fs.readFileSync(inputPath, "utf8"));

        console.log("Generating proof for input:", input.identityCommitment);

        // Generate Full Proof
        const { proof, publicSignals } = await snarkjs.groth16.fullProve(
            input,
            wasmPath,
            zkeyPath
        );

        console.log("Proof generated successfully.");

        // Format for Solidity Verifier
        const calldata = await snarkjs.groth16.exportSolidityCallData(proof, publicSignals);
        
        const proofData = {
            proof: proof,
            publicSignals: publicSignals,
            solidityCalldata: calldata
        };

        const outputPath = path.join(path.dirname(inputPath), "proof.json");
        fs.writeFileSync(outputPath, JSON.stringify(proofData, null, 2));
        
        console.log(`Proof saved to: ${outputPath}`);
        return proofData;
    } catch (error) {
        console.error("Failed to generate proof:", error);
        process.exit(1);
    }
}

// Execution logic for CLI or local testing
if (require.main === module) {
    const args = process.argv.slice(2);
    const input = args[0] || path.join(__dirname, "input.json");
    
    // Note: In a real CI/CD, these paths would point to build artifacts
    const wasm = path.join(__dirname, "build/eligibility_js/eligibility.wasm");
    const zkey = path.join(__dirname, "build/eligibility_final.zkey");

    if (!fs.existsSync(input)) {
        console.error(`Input file not found: ${input}`);
        process.exit(1);
    }

    // Check if build artifacts exist before running
    if (!fs.existsSync(wasm) || !fs.existsSync(zkey)) {
        console.warn("Warning: Circuit artifacts (wasm/zkey) not found. Run 'circom' compilation first.");
        console.log("Mocking proof generation for development flow...");
        
        const mockProof = {
            pi_a: ["0", "0", "0"],
            pi_b: [["0", "0"], ["0", "0"], ["0", "0"]],
            pi_c: ["0", "0", "0"],
            protocol: "groth16"
        };
        fs.writeFileSync(path.join(__dirname, "proof.json"), JSON.stringify(mockProof, null, 2));
    } else {
        generateEligibilityProof(input, wasm, zkey);
    }
}

module.exports = { generateEligibilityProof };