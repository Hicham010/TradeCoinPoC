require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-solhint");
require("hardhat-gas-reporter");
require("solidity-coverage");
require("dotenv").config();

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.4",
        settings: {
          optimizer: {
            enabled: true,
            runs: 9999999,
          },
        },
      },
    ],
  },
  mocha: {
    parallel: true,
  },
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545",
    },
    rinkeby: {
      url: "https://rinkeby.infura.io/v3/" + process.env.INFURA_API_KEY,
      // url: "https://eth-rinkeby.alchemyapi.io/v2/siqDv3HtS8Rfka5jHvor7MazpHj8KFgl",
      accounts: [
        "3e55d582544c0455712429a5d138f97224b359a907d66134ddcba08f69e1944a", // owner
        "6719bf2b3a0f55692d94a2388214d292ffa2307cb59f82e7afe5cee4db5cb920", // farmer
        "40db641515cb3961aa3ddd5e62949bad61ec1cc04518427e704bb75759a3be98", // warehouse
        "49b70739a90d8eda2eed1097d1a9de0c9ad9277c6f87665fd08764dc3dd14103", // transporter
        "6a716d2cd24a4ecb18d9f05e0debf04ae4a281597d70f6972a83615d3012b7dc", // processor
      ],
    },
    arbitrum_rinkeby: {
      url:
        "https://arb-rinkeby.g.alchemy.com/v2/" + process.env.ALCHEMY_API_KEY,
      accounts: [
        "3e55d582544c0455712429a5d138f97224b359a907d66134ddcba08f69e1944a", // owner
      ],
    },
    hardhat: {},
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
  gasReporter: {
    enabled: true,
    currency: "EUR",
    // gasPriceApi: "AB9S78WN3P8XD19I3YJZ7PRZVUCPWT7A5D",
    gasPrice: 40,
    coinmarketcap: process.env.COIN_MCAP_API_KEY,
    excludeContracts: [
      // "ComposableTC/TradeCoinTokenizerV2.sol",
      //"ComposableTC/TradeCoinV4.sol",
      "ComposableTC/RoleControl.sol",
    ],
    rst: true,
  },
};
