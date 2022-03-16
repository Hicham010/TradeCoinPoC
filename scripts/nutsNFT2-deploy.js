const { ethers } = require("hardhat");

async function main() {
  const NutsNFT2 = await hre.ethers.getContractFactory("NutsNFT2");
  const nutsNFT2 = await NutsNFT2.deploy();

  await nutsNFT2.deployed();

  console.log("NutsNFT deployed to: ", nutsNFT2.address);
  // console.log("NutsNFT used a total of: ", greeter.gas);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
