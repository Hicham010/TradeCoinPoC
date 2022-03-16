const { ethers } = require("hardhat");

async function main() {
  const NutsNFT = await hre.ethers.getContractFactory("NutsNFT");
  const nutsNFT = await NutsNFT.deploy();

  await nutsNFT.deployed();

  console.log("NutsNFT deployed to: ", nutsNFT.address);
  // console.log("NutsNFT used a total of: ", greeter.gas);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
