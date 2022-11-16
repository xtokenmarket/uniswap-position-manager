import "@typechain/hardhat";
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-web3";
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-etherscan"
import "hardhat-contract-sizer";
import "hardhat-deploy";
import "hardhat-deploy-ethers"
import { resolve } from "path";

import { config as dotenvConfig } from "dotenv";
import { HardhatUserConfig } from "hardhat/config";

dotenvConfig({ path: resolve(__dirname, "./.env") });

const alchemy = {
  mainnet: 'https://eth-mainnet.alchemyapi.io/v2/',
  arbitrum: 'https://arb-mainnet.g.alchemy.com/v2/',
  optimism: 'https://opt-mainnet.g.alchemy.com/v2/',
  polygon: 'https://polygon-mainnet.g.alchemy.com/v2/',
  goerli: 'https://eth-goerli.alchemyapi.io/v2/'
}

// let adminPrivateKey: string;
// if (!process.env.ADMIN_PRIVATE_KEY) {
//   throw new Error("Please set your ADMIN_PRIVATE_KEY in a .env file");
// } else {
//   adminPrivateKey = process.env.ADMIN_PRIVATE_KEY;
// }

let alchemyKey: string;
if (!process.env.ALCHEMY_KEY) {
  throw new Error("Please set your ALCHEMY_KEY in a .env file");
} else {
  alchemyKey = process.env.ALCHEMY_KEY;
}

let etherscanKey: string;
if (!process.env.ETHERSCAN_API_KEY) {
  throw new Error("Please set your ETHERSCAN_API_KEY in a .env file");
} else {
  etherscanKey = process.env.ETHERSCAN_API_KEY;
}

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      forking: {
        url: alchemy.mainnet + alchemyKey,
        enabled: true,
        blockNumber: 15974600
      }
    },
    // mainnet: {
    //   accounts: [adminPrivateKey],
    //   gasPrice: 50 * 10 ** 9, // 50 gwei
    //   url: alchemy.mainnet + alchemyKey,
    //   timeout: 200000,
    // },
    // goerli: {
    //   accounts: [adminPrivateKey],
    //   url: alchemy.goerli + alchemyKey,
    //   timeout: 200000
    // }
  },
  paths: {
    artifacts: "./artifacts",
    cache: "./cache",
    sources: "./contracts",
    tests: "./test",
  },
  solidity: {
    version: "0.7.6",
    settings: {
      metadata: {
        // Not including the metadata hash
        // https://github.com/paulrberg/solidity-template/issues/31
        bytecodeHash: "none",
      },
      // You should disable the optimizer when debugging
      // https://hardhat.org/hardhat-network/#solidity-optimizer-support
      optimizer: {
        enabled: true,
        runs: 7777,
      },
    },
  },
  etherscan: {
    apiKey: etherscanKey
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: true,
  },
  typechain: {
    outDir: "typechain",
    target: "ethers-v5"
  }
};

export default config;