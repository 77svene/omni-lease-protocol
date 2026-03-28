const { ethers, network } = require("hardhat");

/**
 * OmniLease Core Deployment & Linkage
 * Deploys: LeaseRegistry, ShadowFactory, RentalEngine
 * Links: Registry -> Factory, Engine -> Registry
 */
async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(`Deploying OmniLease Core with: ${deployer.address} on ${network.name}`);

  // 1. Deploy LeaseRegistry
  const LeaseRegistry = await ethers.getContractFactory("LeaseRegistry");
  const registry = await LeaseRegistry.deploy();
  await registry.waitForDeployment();
  const registryAddr = await registry.getAddress();
  console.log(`LeaseRegistry deployed to: ${registryAddr}`);

  // 2. Deploy ShadowFactory
  const ShadowFactory = await ethers.getContractFactory("ShadowFactory");
  const factory = await ShadowFactory.deploy(registryAddr);
  await factory.waitForDeployment();
  const factoryAddr = await factory.getAddress();
  console.log(`ShadowFactory deployed to: ${factoryAddr}`);

  // 3. Deploy RentalEngine
  // Constructor: RentalEngine(address _registry, address _paymentToken)
  // Using a placeholder for USDC or a real address if on mainnet/testnet
  const paymentToken = process.env.PAYMENT_TOKEN || "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"; // Default USDC
  const RentalEngine = await ethers.getContractFactory("RentalEngine");
  const engine = await RentalEngine.deploy(registryAddr, paymentToken);
  await engine.waitForDeployment();
  const engineAddr = await engine.getAddress();
  console.log(`RentalEngine deployed to: ${engineAddr}`);

  // 4. LINKAGE PHASE
  console.log("Starting Linkage Phase...");

  // Set Factory in Registry (Registry needs to know who can mint Shadow NFTs)
  const setFactoryTx = await registry.setShadowFactory(factoryAddr);
  await setFactoryTx.wait();
  console.log("Linked: ShadowFactory set in LeaseRegistry");

  // Authorize Engine in Registry (Engine needs to update lease states)
  const setEngineTx = await registry.setRentalEngine(engineAddr);
  await setEngineTx.wait();
  console.log("Linked: RentalEngine authorized in LeaseRegistry");

  // 5. VERIFICATION (Basic)
  const code = await ethers.provider.getCode(registryAddr);
  if (code === "0x") throw new Error("Deployment failed: No bytecode at Registry address");
  
  console.log("Core Deployment & Linkage Complete.");
  
  // Export addresses for next scripts
  return {
    registry: registryAddr,
    factory: factoryAddr,
    engine: engineAddr
  };
}

if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}

module.exports = main;