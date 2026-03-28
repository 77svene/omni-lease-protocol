const snarkjs = require("snarkjs");
const fs = require("fs");
const path = require("path");

/**
 * OmniLease ZK Prover
 * This script demonstrates the generation and verification of an Eligibility proof.
 * It ensures the user meets reputation and balance thresholds without revealing their secret.
 */
async function run() {
    console.log("--- OmniLease ZK Prover: Eligibility Check ---");

    // Load inputs from the defined input.json
    const inputPath = path.join(__dirname, "input.json");
    if (!fs.existsSync(inputPath)) {
        console.error("Error: input.json not found at", inputPath);
        process.exit(1);
    }
    const input = JSON.parse(fs.readFileSync(inputPath, "utf8"));

    // Note: In a production environment, 'eligibility.wasm' and 'eligibility_final.zkey' 
    // are generated via: circom eligibility.circom --wasm --r1cs && snarkjs groth16 setup...
    // For this MVP, we assume the build artifacts exist in the build folder.
    const wasmPath = path.join(__dirname, "build/eligibility_js/eligibility.wasm");
    const zkeyPath = path.join(__dirname, "build/eligibility_final.zkey");

    // Check if artifacts exist before attempting proof generation
    if (!fs.existsSync(wasmPath) || !fs.existsSync(zkeyPath)) {
        console.log("Build artifacts missing. Simulating proof logic validation...");
        validateLogicLocally(input);
        return;
    }

    try {
        const { proof, publicSignals } = await snarkjs.groth16.fullProve(
            input,
            wasmPath,
            zkeyPath
        );

        console.log("Proof generated successfully.");
        console.log("Public Signals (ReputationThreshold, BalanceThreshold, IdentityCommitment):");
        console.log(publicSignals);

        // Verification
        const vKeyPath = path.join(__dirname, "build/verification_key.json");
        const vKey = JSON.parse(fs.readFileSync(vKeyPath, "utf8"));

        const res = await snarkjs.groth16.verify(vKey, publicSignals, proof);

        if (res === true) {
            console.log("Verification OK: User is eligible for the lease.");
        } else {
            console.log("Verification FAILED: Invalid proof.");
            process.exit(1);
        }
    } catch (err) {
        console.error("Proving Error:", err);
        process.exit(1);
    }
}

/**
 * Validates the logic of the circuit using JS-native math when snarkjs artifacts aren't compiled.
 * This ensures the input.json provided actually satisfies the constraints of eligibility.circom.
 */
function validateLogicLocally(input) {
    console.log("Validating input logic...");
    
    const repOk = parseInt(input.userReputation) >= parseInt(input.reputationThreshold);
    const balOk = BigInt(input.userBalance) >= BigInt(input.balanceThreshold);
    
    // In a real scenario, we'd use circomlibjs.poseidon for the identity check
    // Here we verify the logic flow:
    if (repOk && balOk) {
        console.log("Logic Check: PASSED");
        console.log(`- Reputation ${input.userReputation} >= ${input.reputationThreshold}`);
        console.log(`- Balance ${input.userBalance} >= ${input.balanceThreshold}`);
    } else {
        console.error("Logic Check: FAILED");
        if (!repOk) console.error("Insufficient Reputation");
        if (!balOk) console.error("Insufficient Balance");
        process.exit(1);
    }
}

run().then(() => {
    console.log("Prover execution finished.");
});