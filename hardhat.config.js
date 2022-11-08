require('@nomiclabs/hardhat-ethers');
require('@nomiclabs/hardhat-web3');
require('@nomiclabs/hardhat-waffle');
require('@nomiclabs/hardhat-etherscan');
require('hardhat-contract-sizer');
require('hardhat-deploy');
require('hardhat-deploy-ethers');
require('dotenv').config();

module.exports = {
  networks: {
    hardhat: {
			forking: {
				url: process.env.ALCHEMY_URL,
        enabled: false,
        blockNumber: 15395600
			}
    },
    // mainnet: {
    //   url: process.env.ALCHEMY_URL,
    //   accounts: [process.env.ADMIN_PRIVATE_KEY],
    //   gasPrice: 50000000000,
    //   gas: 8888888
    // },
    // goerli: {
    //   url: process.env.ALCHEMY_URL_GOERLI,
    //   accounts: [process.env.ADMIN_PRIVATE_KEY, process.env.ADMIN_2_PRIVATE_KEY],
    //   //gasPrice: 1100000000,
    //   gas: 7777777
    // }
  },
  // etherscan: {
  //   apiKey: process.env.ETHERSCAN_API_KEY
  // },
  solidity: {
    version: '0.7.6',
    settings: {
      optimizer: {
        enabled: true,
        runs: 100,
      }
    }
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: true,
  }
}
