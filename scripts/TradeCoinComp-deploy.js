const { ethers } = require("hardhat");

async function main() {
  const Tokenizer = await hre.ethers.getContractFactory("TradeCoinTokenizer");
  const tokenizer = await Tokenizer.deploy();

  const Setup = await hre.ethers.getContractFactory("TradeCoinSetup");
  const setup = await Setup.deploy();

  const Rights = await hre.ethers.getContractFactory("TradeCoinRights");
  const rights = await Rights.deploy();

  const Data = await hre.ethers.getContractFactory("TradeCoinData");
  const data = await Data.deploy();

  await tokenizer.deployed();
  await setup.deployed();
  await rights.deployed();
  await data.deployed();

  console.log("TradeCoinCommodity deployed to: ", tokenizer.address);
  console.log("TradeCoinCommodity deployed to: ", setup.address);
  console.log("TradeCoinCommodity deployed to: ", rights.address);
  console.log("TradeCoinCommodity deployed to: ", data.address);

  // console.log("NutsNFT used a total of: ", greeter.gas);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
