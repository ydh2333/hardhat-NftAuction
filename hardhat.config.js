require("@nomicfoundation/hardhat-toolbox");
require('hardhat-deploy');
require("@openzeppelin/hardhat-upgrades")
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.28",
  networks: {
    sepolia: {
      url: `https://sepolia.infura.io/v3/${process.env.INFURA_API_KEY}`,
      accounts: [process.env.PK, process.env.PK_2, process.env.PK_3, process.env.PK_4],
      chainId: 11155111,
    },
    // 配置主网Fork
    hardhat: {
      forking: {
        // 主网RPC端点（Infura）
        url: `https://sepolia.infura.io/v3/${process.env.INFURA_API_KEY}`,
      },
      // 本地Fork节点的链ID（主网链ID是1）
      chainId: 1,
    }
  },
  namedAccounts: {
    deployer: 0,
    user1: 1,
    user2: 2,
    user3: 3
  }
};
