const { expect } = require("chai");
const { ethers } = require("hardhat");

let Nuts;
let nuts;

let owner;
let farmer;
let transporter;
let warehouse;
let accounts;

beforeEach(async function () {
  Nuts = await ethers.getContractFactory("NutsNFT");
  nuts = await Nuts.deploy();
  await nuts.deployed();

  [owner, farmer, transporter, warehouse, ...accounts] =
    await ethers.getSigners();
});

describe("NutsNFT", function () {
  it("Should create an NFT of Nuts and NUT", async function () {
    expect(await nuts.symbol()).to.equal("NUT");
    expect(await nuts.name()).to.equal("Nuts");
  });

  it("Should mint an NFT of type pinda and 1000g ", async function () {
    const pinda_weight = 1000;
    const pinda_type = "pinda";

    const pindaNut = await nuts.mintNut(pinda_weight, pinda_type);
    await pindaNut.wait();

    expect(await nuts.weight_gram(1)).to.equal(pinda_weight);
    expect(await nuts.nut_type(1)).to.equal(pinda_type);
  });

  it("Should check if owner has 1 NFT", async function () {
    const pinda_weight = 1000;
    const pinda_type = "pinda";

    const pindaNut = await nuts.mintNut(pinda_weight, pinda_type);
    await pindaNut.wait();

    expect(await nuts.ownerOf(1)).to.equal(owner.address);
    expect(await nuts.tokenCounter()).to.equal(1);
    expect(await nuts.balanceOf(owner.address)).to.equal(1);
  });

  it("Should decrease weight by owner only", async function () {
    const pinda_weight = 1000;
    const pinda_type = "pinda";
    const decrease = 100;

    const pindaNut = await nuts.mintNut(pinda_weight, pinda_type);
    await pindaNut.wait();

    await expect(
      nuts.connect(farmer).decreaseWeight(decrease, 1)
    ).to.be.revertedWith("You are not the owner");

    const pindaDecreaseOwner = await nuts.decreaseWeight(decrease, 1);
    await pindaDecreaseOwner.wait();

    expect(await nuts.weight_gram(1)).to.equal(pinda_weight - decrease);
  });

  it("Should add an ISO standard to the empty ISO_list", async function () {
    const pinda_weight = 1000;
    const pinda_type = "pinda";
    const ISO_salt = "salt01";

    expect(await nuts.getISOLength(1)).to.equal(0);

    const pindaNut = await nuts.mintNut(pinda_weight, pinda_type);
    await pindaNut.wait();

    await expect(nuts.connect(farmer).addISO(ISO_salt, 1)).to.be.revertedWith(
      "You are not the owner"
    );

    const pindaAddISOOwner = await nuts.addISO(ISO_salt, 1);
    await pindaAddISOOwner.wait();

    expect(await nuts.ISO_list(1, 0)).to.equal(ISO_salt);
    expect(await nuts.getISOLength(1)).to.equal(1);
  });

  it("Should add an ISO list to the empty ISO_list", async function () {
    const pinda_weight = 1000;
    const pinda_type = "pinda";
    const ISO_salt = "salt01";
    const ISO_wash = "wash01";
    const ISO_peel = "peel01";

    const ISO_list = [ISO_peel, ISO_salt, ISO_wash];

    expect(await nuts.getISOLength(1)).to.equal(0);

    const pindaNut = await nuts.mintNut(pinda_weight, pinda_type);
    await pindaNut.wait();

    await expect(
      nuts.connect(farmer).addISOList(ISO_list, 1)
    ).to.be.revertedWith("You are not the owner");

    const pindaAddISOOwner = await nuts.addISOList(ISO_list, 1);
    await pindaAddISOOwner.wait();

    expect(await nuts.ISO_list(1, 0)).to.equal(ISO_peel);
    expect(await nuts.ISO_list(1, 1)).to.equal(ISO_salt);
    expect(await nuts.ISO_list(1, 2)).to.equal(ISO_wash);

    expect(await nuts.getISOLength(1)).to.equal(3);
  });

  it("Should batch 2 pinda's by the owner", async function () {
    const pinda_weight = 1000;
    const pinda_type = "pinda";
    const ISO_salt = "salt01";

    const pindaNut1 = await nuts.mintNut(pinda_weight, pinda_type);
    await pindaNut1.wait();

    const pindaNut2 = await nuts.mintNut(pinda_weight, pinda_type);
    await pindaNut2.wait();

    const pindaNut3 = await nuts.mintNut(pinda_weight, pinda_type);
    await pindaNut3.wait();

    const pindaAddISOOwner = await nuts.addISO(ISO_salt, 3);
    await pindaAddISOOwner.wait();

    const cashew_weight = 400;
    const cashew_type = "cashew";

    const cashewNut4 = await nuts.mintNut(cashew_weight, cashew_type);
    await cashewNut4.wait();

    await expect(nuts.connect(farmer).batchNuts(1, 2)).to.be.revertedWith(
      "You are not the owner both NFT's"
    );

    await expect(nuts.connect(owner).batchNuts(1, 4)).to.be.revertedWith(
      "The nuts have to be the same kind"
    );

    await expect(nuts.connect(owner).batchNuts(1, 3)).to.be.revertedWith(
      "The nuts have to have the same ISO processes"
    );

    const batchPinda1_2 = await nuts.batchNuts(1, 2);
    await batchPinda1_2.wait();

    expect(await nuts.weight_gram(1)).to.equal(0);
    expect(await nuts.weight_gram(2)).to.equal(0);

    expect(await nuts.nut_type(1)).to.equal(await nuts.nut_type(5));
    expect(await nuts.nut_type(2)).to.equal(await nuts.nut_type(5));

    expect(await nuts.ownerOf(5)).to.equal(owner.address);

    await expect(nuts.ownerOf(1)).to.be.revertedWith(
      "ERC721: owner query for nonexistent token"
    );

    await expect(nuts.ownerOf(2)).to.be.revertedWith(
      "ERC721: owner query for nonexistent token"
    );
  });

  it("Should approve NFT's for receiver to be deliverd by the transporter", async function () {
    const pinda_weight = 1000;
    const pinda_type = "pinda";

    const pindaNut1 = await nuts.mintNut(pinda_weight, pinda_type);
    await pindaNut1.wait();
    const pindaNut2 = await nuts.mintNut(pinda_weight, pinda_type);
    await pindaNut2.wait();

    const pindaNuts = [1, 2];

    await expect(
      nuts
        .connect(farmer)
        .transport(transporter.address, warehouse.address, pindaNuts)
    ).to.be.revertedWith("You are not the owner");

    const approveNutForTransport = await nuts.transport(
      transporter.address,
      warehouse.address,
      pindaNuts
    );
    await approveNutForTransport.wait();

    expect(
      await nuts.getCargoByIndex(transporter.address, warehouse.address, 0)
    ).to.equal(pindaNuts[0]);
    expect(
      await nuts.getCargoByIndex(transporter.address, warehouse.address, 1)
    ).to.equal(pindaNuts[1]);
  });

  it("Should transfer NFT's from owner to be receiver by and thereby approve delivery", async function () {
    const pinda_weight = 1000;
    const pinda_type = "pinda";

    const pindaNut1 = await nuts.mintNut(pinda_weight, pinda_type);
    await pindaNut1.wait();
    const pindaNut2 = await nuts.mintNut(pinda_weight, pinda_type);
    await pindaNut2.wait();

    const pindaNuts = [1, 2];

    const approveNutForTransport = await nuts.transport(
      transporter.address,
      warehouse.address,
      pindaNuts
    );
    await approveNutForTransport.wait();

    await expect(
      nuts
        .connect(farmer)
        .delivered(transporter.address, owner.address, pindaNuts)
    ).to.be.revertedWith("You are not the owner of this cargo");

    expect(
      await nuts.getCargoByIndex(transporter.address, warehouse.address, 0)
    ).to.equal(pindaNuts[0]);
    expect(
      await nuts.getCargoByIndex(transporter.address, warehouse.address, 1)
    ).to.equal(pindaNuts[1]);

    const pickUpNutByWarehouse = await nuts
      .connect(warehouse)
      .delivered(transporter.address, owner.address, pindaNuts);
    await pickUpNutByWarehouse.wait();

    expect(await nuts.ownerOf(1)).to.equal(warehouse.address);
    expect(await nuts.ownerOf(2)).to.equal(warehouse.address);

    await expect(
      nuts.getCargoByIndex(transporter.address, warehouse.address, 0)
    ).to.be.reverted;
    await expect(
      nuts.getCargoByIndex(transporter.address, warehouse.address, 1)
    ).to.be.reverted;
  });
});
