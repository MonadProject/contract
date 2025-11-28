const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  const net = await hre.ethers.provider.getNetwork();
  const chainIdPre = Number(net.chainId);
  const name = hre.network.name;
  const isLocal = name === "localhost" || chainIdPre === 31337;
  const isMonadTestnet = name === "monad" || chainIdPre === 10143;
  console.log(
    `开始部署 SimpleAuction -> 网络: ${name} (${
      isLocal ? "本地" : "测试网"
    }) | chainId=${chainIdPre}`
  );

  const SimpleAuction = await hre.ethers.getContractFactory("SimpleAuction");
  const [deployer] = await hre.ethers.getSigners();
  const bal = await hre.ethers.provider.getBalance(deployer.address);
  console.log(
    `使用账户: ${deployer.address}, 余额: ${hre.ethers.formatEther(bal)} MON`
  );
  const auction = await SimpleAuction.deploy();
  await auction.waitForDeployment();
  const address = await auction.getAddress();
  const network = await hre.ethers.provider.getNetwork();
  const chainId = Number(network.chainId);
  console.log(`部署成功，合约地址: ${address}`);
  if (isMonadTestnet) {
    console.log(`区块浏览器: https://explorer.monad.xyz/address/${address}`);
  } else {
    console.log(`本地RPC: http://127.0.0.1:8545/`);
  }

  const frontendConfigPath = path.resolve(
    __dirname,
    "../../front/src/config/deployed.json"
  );
  const backendConfigPath = path.resolve(
    __dirname,
    "../../backend/config/deployed.json"
  );

  // 写入前后端配置
  const config = {
    contractAddress: address,
    chainId: chainId,
    deployTime: new Date().toISOString(),
  };

  try {
    if (fs.existsSync(path.dirname(frontendConfigPath))) {
      fs.writeFileSync(frontendConfigPath, JSON.stringify(config, null, 2));
      console.log("已写入前端配置: front/src/config/deployed.json");
    } else {
      console.log("未找到前端路径，跳过写入");
    }

    try {
      fs.mkdirSync(path.dirname(backendConfigPath), { recursive: true });
      fs.writeFileSync(backendConfigPath, JSON.stringify(config, null, 2));
      console.log("已写入后端配置: backend/config/deployed.json");
    } catch (e) {
      console.log("写入后端配置失败:", e.message);
    }
  } catch (e) {
    console.log("写入前端配置失败:", e.message);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
