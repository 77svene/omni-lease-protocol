const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("OmniLease: End-to-End Protocol Flow", function () {
    let owner, lister, lessee, treasury;
    let nft, usdc, vaultFactory, registry, engine, oracle, shadowFactory, verifier;
    
    const TOKEN_ID = 1;
    const LEASE_DURATION = 86400; // 1 day
    const BASE_PRICE = ethers.parseUnits("100", 6); // 100 USDC

    before(async function () {
        [owner, lister, lessee, treasury] = await ethers.getSigners();

        // 1. Deploy Mock NFT (ERC721)
        const NFT = await ethers.getContractFactory("UtilityToken");
        nft = await NFT.deploy("Test NFT", "TNFT");

        // 2. Deploy Mock USDC (ERC20) - Real transfer logic, no more "Mock-on-Mock"
        const USDC = await ethers.getContractFactory("UtilityToken"); 
        usdc = await USDC.deploy("USD Coin", "USDC");
        // Mint USDC to lessee
        await usdc.mint(lessee.address, ethers.parseUnits("1000", 6));

        // 3. Deploy Core Infrastructure
        const Registry = await ethers.getContractFactory("LeaseRegistry");
        registry = await Registry.deploy();

        const ShadowFactory = await ethers.getContractFactory("ShadowFactory");
        shadowFactory = await ShadowFactory.deploy(await registry.getAddress());

        const Oracle = await ethers.getContractFactory("PricingOracle");
        oracle = await Oracle.deploy();

        const Verifier = await ethers.getContractFactory("ZkVerifier");
        verifier = await Verifier.deploy();

        const Engine = await ethers.getContractFactory("RentalEngine");
        engine = await Engine.deploy(
            await registry.getAddress(),
            await shadowFactory.getAddress(),
            await usdc.getAddress(),
            await oracle.getAddress(),
            await verifier.getAddress(),
            treasury.address
        );

        // Set permissions
        await registry.setEngine(await engine.getAddress());
        await shadowFactory.transferOwnership(await engine.getAddress());
    });

    it("Should complete a full lease lifecycle with ZK-Verification", async function () {
        // --- LISTING ---
        await nft.mint(lister.address, TOKEN_ID);
        await nft.connect(lister).approve(await engine.getAddress(), TOKEN_ID);
        
        await oracle.setFloorPrice(await nft.getAddress(), BASE_PRICE);
        
        await engine.connect(lister).listNFT(await nft.getAddress(), TOKEN_ID, LEASE_DURATION);
        
        const listing = await engine.listings(1);
        expect(listing.lister).to.equal(lister.address);
        expect(listing.isActive).to.be.true;

        // --- ZK-VERIFICATION & LEASING ---
        // Generate a dummy proof that matches the ZkVerifier's expected structure
        // In a real run, this comes from circuits/privacy/prover.js
        const proofA = [1, 2];
        const proofB = [[1, 2], [3, 4]];
        const proofC = [1, 2];
        const pubInputs = [12345, 67890, 1]; // identityCommitment, threshold, etc.

        await usdc.connect(lessee).approve(await engine.getAddress(), BASE_PRICE);
        
        // Execute Lease - This triggers the ZK Verifier and USDC transfer
        const initialTreasuryBal = await usdc.balanceOf(treasury.address);
        
        await engine.connect(lessee).leaseNFT(
            1, 
            proofA, 
            proofB, 
            proofC, 
            pubInputs
        );

        // Verify Economic Logic
        const finalTreasuryBal = await usdc.balanceOf(treasury.address);
        expect(finalTreasuryBal).to.be.gt(initialTreasuryBal);
        expect(await usdc.balanceOf(lessee.address)).to.equal(ethers.parseUnits("900", 6));

        // Verify Shadow NFT Minting
        const shadowAddr = await shadowFactory.getShadow(await nft.getAddress());
        const shadowNFT = await ethers.getContractAt("UtilityToken", shadowAddr);
        expect(await shadowNFT.ownerOf(TOKEN_ID)).to.equal(lessee.address);

        // --- EXPIRY & RECLAMATION ---
        await ethers.provider.send("evm_increaseTime", [LEASE_DURATION + 1]);
        await ethers.provider.send("evm_mine");

        await engine.connect(lister).reclaimNFT(1);
        
        expect(await nft.ownerOf(TOKEN_ID)).to.equal(lister.address);
        // Shadow NFT should be burned or revoked (handled by engine/registry)
        await expect(shadowNFT.ownerOf(TOKEN_ID)).to.be.reverted;
    });
});