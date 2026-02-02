import { config as dotenvConfig } from "dotenv";
import "@nomicfoundation/hardhat-toolbox";

dotenvConfig();

/** @type import('hardhat/config').HardhatUserConfig */
export default {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    // 0G MAINNET (Production)
    zerog_mainnet: {
      url: process.env.ZEROG_RPC_URL || "https://evmrpc.0g.ai",
      chainId: 16661,
      accounts: process.env.DEPLOYER_PRIVATE_KEY ? [process.env.DEPLOYER_PRIVATE_KEY] : [],
      gasPrice: "auto",
      gas: "auto"
    },
    // 0G Testnet (Testing only)
    zerog_testnet: {
      url: "https://evmrpc-testnet.0g.ai",
      chainId: 16600,
      accounts: process.env.DEPLOYER_PRIVATE_KEY ? [process.env.DEPLOYER_PRIVATE_KEY] : [],
      gasPrice: "auto",
      gas: "auto"
    },
    // Local development
    hardhat: {
      chainId: 1337
    }
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  }
};