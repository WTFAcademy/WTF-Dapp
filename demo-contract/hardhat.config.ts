import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox-viem";

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    sepolia: {
      url: "https://api.zan.top/public/eth-sepolia", // 实际项目中需要替换为你的 ZAN 的 RPC 地址，这里用的是测试用的公共地址，可能不稳定
      accounts: ["YOUR_PRIVATE_KEY"], // 替换为你的钱包私钥
    },
  },
  etherscan: {
    apiKey: {
      sepolia: "YOUR_ETHERSCAN_API_KEY", // 替换为你的 Etherscan API Key
    },
  },
};

export default config;
