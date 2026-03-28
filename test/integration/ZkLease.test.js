const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("OmniLease: ZK-Integrated Lease Lifecycle", function () {
    let owner, lister, lessee, treasury;
    let nft, usdc, registry, factory, engine, verifier, proofRegistry;
    
    const TOKEN_ID = 1;
    const LEASE_DURATION = 86400; // 1 day
    const PRICE_PER_SECOND = ethers.parseUnits("0.0001", 6); // USDC 6 decimals
    const TOTAL_PRICE = BigInt(LEASE_DURATION) * PRICE_PER_SECOND;

    beforeEach(async function () {
        [owner, lister, lessee, treasury] = await ethers.getSigners();

        // 1. Deploy Mock Assets
        const MockNFT = await ethers.getContractFactory("UtilityToken");
        nft = await MockNFT.deploy();
        const MockUSDC = await ethers.getContractFactory("FeeDistributor"); // Reusing as ERC20 mock
        usdc = await MockUSDC.deploy();

        // 2. Deploy Core Protocol
        const Verifier = await ethers.getContractFactory("ZkVerifier");
        verifier = await Verifier.deploy();

        const ProofRegistry = await ethers.getContractFactory("ProofRegistry");
        proofRegistry = await ProofRegistry.deploy();

        const Registry = await ethers.getContractFactory("LeaseRegistry");
        registry = await Registry.deploy();

        const Factory = await ethers.getContractFactory("ShadowFactory");
        factory = await Factory.deploy(await registry.getAddress());

        const Engine = await ethers.getContractFactory("RentalEngine");
        engine = await Engine.deploy(
            await registry.getAddress(),
            await factory.getAddress(),
            await usdc.getAddress(),
            await verifier.getAddress()
        );

        // 3. Setup Permissions
        await registry.setEngine(await engine.getAddress());
        await factory.setEngine(await engine.getAddress());

        // 4. Prepare Assets
        await nft.mint(lister.address, TOKEN_ID);
        await nft.connect(lister).approve(await engine.getAddress(), TOKEN_ID);
        await usdc.mint(lessee.address, TOTAL_PRICE * 2n);
        await usdc.connect(lessee).approve(await engine.getAddress(), TOTAL_PRICE * 2n);
    });

    it("Should fail lease if ZK proof is missing or invalid", async function () {
        await engine.connect(lister).listNFT(await nft.getAddress(), TOKEN_ID, PRICE_PER_SECOND);
        
        // Attempt to lease without registering a proof first
        await expect(
            engine.connect(lessee).leaseNFT(await nft.getAddress(), TOKEN_ID, LEASE_DURATION)
        ).to.be.revertedWith("Eligibility proof not found");
    });

    it("Should complete full ZK-verified lease lifecycle", async function () {
        // 1. Listing
        await engine.connect(lister).listNFT(await nft.getAddress(), TOKEN_ID, PRICE_PER_SECOND);

        // 2. ZK Proof Registration (Simulating off-chain proof generation)
        // Public inputs for Eligibility.circom: [reputationThreshold, balanceThreshold, identityCommitment]
        const mockProof = {
            a: [1, 2],
            b: [[3, 4], [5, 6]],
            c: [7, 8],
            input: [50, 100, 12345] // Rep > 50, Bal > 100
        };

        // Register proof in ProofRegistry (which the Engine checks)
        // Note: In our architecture, the Engine calls the Verifier directly or checks a registry.
        // We'll simulate the Engine's internal check passing after a valid proof is submitted.
        
        // 3. Lease Execution
        // We assume the Engine calls verifier.verifyProof(a, b, c, input)
        // For the test, we provide the proof data to the lease call
        await engine.connect(lessee).leaseNFTWithProof(
            await nft.getAddress(), 
            TOKEN_ID, 
            LEASE_DURATION,
            mockProof.a,
            mockProof.b,
            mockProof.c,
            mockProof.input
        );

        // 4. Verify Shadow NFT Minting
        const shadowAddr = await factory.getShadow(await nft.getAddress(), TOKEN_ID);
        expect(shadowAddr).to.not.equal(ethers.ZeroAddress);
        
        const shadowNFT = await ethers.getContractAt("UtilityToken", shadowAddr);
        expect(await shadowNFT.ownerOf(TOKEN_ID)).to.equal(lessee.address);

        // 5. Expiry & Reclamation
        await ethers.provider.send("evm_increaseTime", [LEASE_DURATION + 1]);
        await ethers.provider.send("evm_mine");

        await engine.connect(lister).reclaimNFT(await nft.getAddress(), TOKEN_ID);
        
        expect(await nft.ownerOf(TOKEN_ID)).to.equal(lister.address);
        // Shadow should be burned or inaccessible
        await expect(shadowNFT.ownerOf(TOKEN_ID)).to.be.reverted;
    });

    it("Should reject lease if ZK proof inputs don't meet thresholds", async function () {
        await engine.connect(lister).listNFT(await nft.getAddress(), TOKEN_ID, PRICE_PER_SECOND);

        const failingInputs = [10, 100, 12345]; // Rep 10 < Threshold 50
        const mockProof = {
            a: [1, 2],
            b: [[3, 4], [5, 6]],
            c: [7, 8],
            input: failingInputs
        };

        await expect(
            engine.connect(lessee).leaseNFTWithProof(
                await nft.getAddress(), 
                TOKEN_ID, 
                LEASE_DURATION,
                mockProof.a,
                mockProof.b,
                mockProof.c,
                mockProof.input
            )
        ).to.be.revertedWith("Insufficient reputation");
    });
});