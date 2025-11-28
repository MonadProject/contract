require("dotenv").config();
require("@nomicfoundation/hardhat-toolbox");

module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    monad: {
      url: process.env.MONAD_RPC_URL || "https://monad-testnet.drpc.org",
      accounts: process.env.PRIVATE_KEY
        ? [
            process.env.PRIVATE_KEY.startsWith("0x")
              ? process.env.PRIVATE_KEY
              : "0x" + process.env.PRIVATE_KEY,
          ]
        : [],
      chainId: 10143,
    },
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
};
