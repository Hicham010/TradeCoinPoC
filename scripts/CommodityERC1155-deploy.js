const { ethers } = require("hardhat");

async function main() {
  const Commodity = await hre.ethers.getContractFactory("TradeCoinCommodity");
  const commodity = await Commodity.deploy();

  await commodity.deployed();

  console.log("TradeCoinCommodity deployed to: ", commodity.address);
  // console.log("NutsNFT used a total of: ", greeter.gas);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
