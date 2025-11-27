const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  console.log("Deploying SimpleAuction to Monad...");

  const SimpleAuction = await hre.ethers.getContractFactory("SimpleAuction");
  const auction = await SimpleAuction.deploy();
  await auction.waitForDeployment();
  const address = await auction.getAddress();
  const network = await hre.ethers.provider.getNetwork();
  const chainId = Number(network.chainId);

  console.log("SimpleAuction deployed to:", address);
  console.log("Save this address for frontend");
  console.log("Explorer:", `https://explorer.monad.xyz/address/${address}`);

  const legacyFrontendPath = path.resolve(
    __dirname,
    "../frontend/src/config/deployed.json"
  );
  const frontendConfigPath = path.resolve(
    __dirname,
    "../front/src/config/deployed.json"
  );
  const config = {
    contractAddress: address,
    chainId: chainId,
    deployTime: new Date().toISOString(),
  };

  try {
    if (fs.existsSync(path.dirname(frontendConfigPath))) {
      fs.writeFileSync(frontendConfigPath, JSON.stringify(config, null, 2));
      console.log("Config saved to front/src/config/deployed.json");
    } else if (fs.existsSync(path.dirname(legacyFrontendPath))) {
      fs.writeFileSync(legacyFrontendPath, JSON.stringify(config, null, 2));
      console.log("Config saved to frontend/src/config/deployed.json");
    } else {
      console.log("frontend path not found, skipping config write");
    }
  } catch (e) {
    console.log("Failed to write frontend config:", e.message);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
