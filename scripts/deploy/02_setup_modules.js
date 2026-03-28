const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Setting up modules with account:", deployer.address);

  // 1. Deploy Pricing Oracle
  const PricingOracle = await ethers.getContractFactory("PricingOracle");
  const oracle = await PricingOracle.deploy();
  await oracle.waitForDeployment();
  const oracleAddress = await oracle.getAddress();
  console.log("PricingOracle deployed to:", oracleAddress);

  // 2. Deploy Fee Distributor
  // Assuming USDC address for local/testnet or a placeholder for MVP
  const mockUsdcAddress = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"; 
  const FeeDistributor = await ethers.getContractFactory("FeeDistributor");
  const distributor = await FeeDistributor.deploy(mockUsdcAddress);
  await distributor.waitForDeployment();
  const distributorAddress = await distributor.getAddress();
  console.log("FeeDistributor deployed to:", distributorAddress);

  // 3. Configure Oracle Defaults
  // Set a floor price for a test collection (e.g., Bored Ape or similar mock)
  const mockCollection = "0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D";
  const floorPrice = ethers.parseUnits("0.1", 18); // 0.1 ETH/USDC equivalent
  const tx = await oracle.updateFloorPrice(mockCollection, floorPrice);
  await tx.wait();
  console.log(`Floor price for ${mockCollection} set to 0.1`);

  // 4. Save addresses for next step
  console.log("--- MODULES READY ---");
  console.log(`ORACLE_ADDR=${oracleAddress}`);
  console.log(`DISTRIBUTOR_ADDR=${distributorAddress}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });