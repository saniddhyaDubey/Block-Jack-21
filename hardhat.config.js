require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  paths: {
    artifacts: "./client/src/artifacts",
  },
  solidity: {
    compilers: [
      {
        version: "0.8.20",
      },
      {
        version: "0.8.19",
      },
    ],
  },
  networks: {
    sepolia: {
      url: "https://sepolia.infura.io/v3/84475747653645b18cd6327dd826200d",
      accounts: ["9a1c397fed3aba704232fea1a37a96e67c98e5b03e9c8c3220b7d255a6553fe8"]
    },
    fhenix: {
      url: "https://api.helium.fhenix.zone/",
      accounts: [""]
    }
  }
};