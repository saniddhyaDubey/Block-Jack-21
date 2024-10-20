const hre = require("hardhat");

async function main() {
  // Get the contract factory
  const BlackJack = await hre.ethers.getContractFactory("contracts/Fhenix.sol:BlackJack");

  // Deploy the contract
  console.log("Deploying BlackJack contract...");
  const blackJack = await BlackJack.deploy();

  // Wait for the deployment transaction to be mined
  await blackJack.waitForDeployment();

  // Get the deployed contract address
  const deployedAddress = await blackJack.getAddress();

  console.log("BlackJack contract deployed to:", deployedAddress);
}

// Run the deployment
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });