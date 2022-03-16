const { expect } = require("chai");
const { ethers } = require("hardhat");

let Commodity;
let commodity;

let admin;
let owner;
let farmer;
let transporter;
let warehouse;
let processor;
let notApproved;
let accounts;

let address0;

let commodityState = {
  PendingConfirmation: 0,
  Confirmed: 1,
  PendingProcess: 2,
  Processing: 3,
  PendingTransport: 4,
  Transporting: 5,
  PendingStorage: 6,
  Stored: 7,
  EOL: 8,
};

function allAddr() {
  console.log("address of admin", admin.address);
  console.log("address of owner", owner.address);
  console.log("address of farmer", farmer.address);
  console.log("address of transporter", transporter.address);
  console.log("address of warehouse", warehouse.address);
  console.log("address of processor", processor.address);
}

beforeEach(async function () {
  Commodity = await ethers.getContractFactory("TradeCoinCommodity");
  commodity = await Commodity.deploy();
  await commodity.deployed();

  [
    admin,
    owner,
    farmer,
    transporter,
    warehouse,
    processor,
    notApproved,
    ...accounts
  ] = await ethers.getSigners();

  address0 = "0x0000000000000000000000000000000000000000";

  await commodity.connect(admin).grantAllRolesForOwner(owner.address);
  await commodity.connect(owner).grantFarmerRole(farmer.address);
  await commodity.connect(owner).grantWarehouseRole(warehouse.address);
  await commodity.connect(owner).grantTransporterRole(transporter.address);
  await commodity.connect(owner).grantProcessorRole(processor.address);
});

describe("TradeCoinCommodity", function () {
  it("Do supply chain participants have a role", async function () {
    expect(await commodity.hasRole(commodity.OWNER_ROLE(), owner.address));
    expect(await commodity.hasRole(commodity.FARMER_ROLE(), farmer.address));
    expect(
      await commodity.hasRole(commodity.TRANSPORTER_ROLE(), transporter.address)
    );
    expect(
      await commodity.hasRole(commodity.PROCCESOR_ROLE(), processor.address)
    );
    expect(
      await commodity.hasRole(commodity.WAREHOUSE_ROLE(), warehouse.address)
    );
  });

  it("Mint commodity by farmer and owner only", async function () {
    const weightGram = 1000;
    const commodityType = "pinda";
    expect(
      await commodity
        .connect(farmer)
        .mintCommodity(weightGram, commodityType, warehouse.address)
    );

    await expect(
      commodity
        .connect(farmer)
        .mintCommodity(weightGram, commodityType, processor.address)
    ).to.be.revertedWith("Address is not an approved warehouse");

    expect(
      await commodity
        .connect(owner)
        .mintCommodity(weightGram, commodityType, warehouse.address)
    );

    expect(await commodity.balanceOf(farmer.address, 0)).to.equal(weightGram);
    expect(await commodity.typeCommodityOf(0)).to.equal(commodityType);
    expect(await commodity.stateCommodityOf(0)).to.equal(
      commodityState.PendingConfirmation
    );
    expect(await commodity.ownerOf(0)).to.equal(farmer.address);
    expect(await commodity.isoListLengthOf(0)).to.equal(0);
    expect(await commodity.balanceOfOwners(farmer.address)).to.equal(1);

    expect(await commodity.balanceOf(owner.address, 1)).to.equal(weightGram);
    expect(await commodity.typeCommodityOf(1)).to.equal(commodityType);
    expect(await commodity.stateCommodityOf(1)).to.equal(
      commodityState.PendingConfirmation
    );
    expect(await commodity.isoListLengthOf(1)).to.equal(0);
    expect(await commodity.ownerOf(1)).to.equal(owner.address);
    expect(await commodity.balanceOfOwners(owner.address)).to.equal(1);
  });

  it("Minting not allowed by unapproved farmer", async function () {
    const weightGram = 1000;
    const commodityType = "pinda";
    await expect(
      commodity
        .connect(processor)
        .mintCommodity(weightGram, commodityType, warehouse.address)
    ).to.be.reverted;

    await expect(
      commodity
        .connect(notApproved)
        .mintCommodity(weightGram, commodityType, warehouse.address)
    ).to.be.reverted;
  });

  it("Minting paused", async function () {
    expect(await commodity.connect(admin).pause());

    const weightGram = 1000;
    const commodityType = "pinda";
    await expect(
      commodity
        .connect(farmer)
        .mintCommodity(weightGram, commodityType, warehouse.address)
    ).to.be.reverted;

    await expect(
      commodity
        .connect(owner)
        .mintCommodity(weightGram, commodityType, warehouse.address)
    ).to.be.reverted;
    expect(await commodity.balanceOf(farmer.address, 0)).to.equal(0);
    await expect(commodity.dataOf(0)).to.be.revertedWith(
      "ERC1155: data query for zero address"
    );
    await expect(commodity.stateCommodityOf(0)).to.be.revertedWith(
      "ERC1155: data query for zero address"
    );
  });

  it("Warehouse confirmed commodity", async function () {
    const weightGram = 1000;
    const commodityType = "pinda";
    expect(
      await commodity
        .connect(farmer)
        .mintCommodity(weightGram, commodityType, warehouse.address)
    );
    expect(
      await commodity.connect(warehouse).confirmCommodity(0, owner.address)
    );

    expect(await commodity.balanceOf(farmer.address, 0)).to.equal(0);
    expect(await commodity.balanceOf(warehouse.address, 0)).to.equal(
      weightGram
    );
    expect(await commodity.stateCommodityOf(0)).to.equal(
      commodityState.Confirmed
    );
    expect(await commodity.ownerOf(0)).to.equal(owner.address);
  });

  it("Warehouse confirm commodity for unapproved owner", async function () {
    const weightGram = 1000;
    const commodityType = "pinda";
    expect(
      await commodity
        .connect(farmer)
        .mintCommodity(weightGram, commodityType, warehouse.address)
    );
    await expect(
      commodity.connect(warehouse).confirmCommodity(0, notApproved.address)
    ).to.be.reverted;
  });

  it("Confirming not minted commodity by warehouse", async function () {
    await expect(
      commodity.connect(warehouse).confirmCommodity(0, owner.address)
    ).to.be.revertedWith("ERC1155: data query for zero address");
  });

  it("Confirming commodity by not approved warehouse or approved owner", async function () {
    const weightGram = 1000;
    const commodityType = "pinda";
    expect(
      await commodity
        .connect(farmer)
        .mintCommodity(weightGram, commodityType, warehouse.address)
    );
    await expect(
      commodity.connect(notApproved).confirmCommodity(0, owner.address)
    ).to.be.reverted;

    await expect(
      commodity.connect(warehouse).confirmCommodity(0, notApproved.address)
    ).to.be.revertedWith("Address is not an approved owner");

    expect(await commodity.balanceOf(farmer.address, 0)).to.equal(weightGram);
    expect(await commodity.ownerOf(0)).to.equal(farmer.address);
  });

  it("Sell ownership of commodity for eth", async function () {
    const secondOwner = accounts[9];
    await commodity.connect(admin).grantAllRolesForOwner(secondOwner.address);
    const weightGram = 1000;
    const commodityType = "pinda";
    expect(
      await commodity
        .connect(farmer)
        .mintCommodity(weightGram, commodityType, warehouse.address)
    );
    expect(
      await commodity.connect(warehouse).confirmCommodity(0, owner.address)
    );
    expect(
      await commodity
        .connect(owner)
        .setPriceForOwnership(0, 1000, secondOwner.address, false)
    );
    expect(
      await commodity.connect(secondOwner).payForOwnership(0, { value: 1000 })
    );
    expect(await commodity.ownerOf(0)).to.equal(secondOwner.address);
  });

  it("Sell ownership of commodity for fiat", async function () {
    const secondOwner = accounts[9];
    await commodity.connect(admin).grantAllRolesForOwner(secondOwner.address);
    const weightGram = 1000;
    const commodityType = "pinda";
    expect(
      await commodity
        .connect(farmer)
        .mintCommodity(weightGram, commodityType, warehouse.address)
    );
    expect(
      await commodity.connect(warehouse).confirmCommodity(0, owner.address)
    );
    expect(
      await commodity
        .connect(owner)
        .setPriceForOwnership(0, 0, secondOwner.address, true)
    );
    expect(await commodity.connect(secondOwner).payForOwnership(0));
    expect(await commodity.ownerOf(0)).to.equal(secondOwner.address);
  });

  it("Sell ownership for commodity that is pending confirmation and not a owner", async function () {
    const secondOwner = accounts[9];
    await commodity.connect(admin).grantAllRolesForOwner(secondOwner.address);
    const weightGram = 1000;
    const commodityType = "pinda";
    expect(
      await commodity
        .connect(farmer)
        .mintCommodity(weightGram, commodityType, warehouse.address)
    );
    await expect(
      commodity
        .connect(farmer)
        .setPriceForOwnership(0, 1000, secondOwner.address, false)
    ).to.be.reverted;
  });

  it("Sell ownership for commodity to not approved owner", async function () {
    const secondOwner = accounts[9];
    // await commodity.connect(admin).grantAllRolesForOwner(secondOwner.address);
    const weightGram = 1000;
    const commodityType = "pinda";
    expect(
      await commodity
        .connect(farmer)
        .mintCommodity(weightGram, commodityType, warehouse.address)
    );
    expect(
      await commodity.connect(warehouse).confirmCommodity(0, owner.address)
    );
    expect(
      await commodity
        .connect(owner)
        .setPriceForOwnership(0, 1000, secondOwner.address, false)
    );
    await expect(
      commodity.connect(secondOwner).payForOwnership(0, { value: 1000 })
    ).to.be.reverted;
  });

  it("Batching 3 tokens by approved warehouse", async function () {
    const weightGram = 1000;
    const commodityType = "pinda";
    const idList = [0, 1, 2];
    for (i = 0; i < idList.length; i++) {
      await commodity
        .connect(farmer)
        .mintCommodity(weightGram, commodityType, warehouse.address);
      await commodity.connect(warehouse).confirmCommodity(i, owner.address);
      expect(await commodity.ownerOf(i)).to.equal(owner.address);
    }

    expect(await commodity.balanceOfOwners(owner.address)).to.equal(
      idList.length
    );

    await commodity.connect(warehouse).batchTokens(idList);

    expect(await commodity.stateCommodityOf(idList.length + 1)).to.equal(
      commodityState.Confirmed
    );
    // dataOf = await commodity.dataOf(idList.length + 1);
    // console.log(dataOf);

    expect(
      await commodity.balanceOf(warehouse.address, idList.length + 1)
    ).to.equal(weightGram * idList.length);

    expect(await commodity.ownerOf(idList.length + 1)).to.equal(owner.address);
    expect(await commodity.balanceOfOwners(owner.address)).to.equal(1);

    for (i = 0; i < idList.length; i++) {
      expect(await commodity.ownerOf(i)).to.equal(address0);
    }
    for (i = 0; i < idList.length; i++) {
      expect(await commodity.balanceOf(warehouse.address, i)).to.equal(0);
    }
  });

  it("Batching 6 tokens by approved warehouse", async function () {
    const weightGram = 1000;
    const commodityType = "pinda";
    const idList = [0, 1, 2, 3, 4, 5];
    for (i = 0; i < idList.length; i++) {
      await commodity
        .connect(farmer)
        .mintCommodity(weightGram, commodityType, warehouse.address);
      await commodity.connect(warehouse).confirmCommodity(i, owner.address);
      expect(await commodity.ownerOf(i)).to.equal(owner.address);
    }
    expect(await commodity.balanceOfOwners(owner.address)).to.equal(
      idList.length
    );

    await commodity.connect(warehouse).batchTokens(idList);

    expect(await commodity.stateCommodityOf(idList.length + 1)).to.equal(
      commodityState.Confirmed
    );

    expect(
      await commodity.balanceOf(warehouse.address, idList.length + 1)
    ).to.equal(weightGram * idList.length);
    expect(await commodity.ownerOf(idList.length + 1)).to.equal(owner.address);
    expect(await commodity.balanceOfOwners(owner.address)).to.equal(1);

    for (i = 0; i < idList.length; i++) {
      expect(await commodity.ownerOf(i)).to.equal(address0);
    }
    for (i = 0; i < idList.length; i++) {
      expect(await commodity.balanceOf(warehouse.address, i)).to.equal(0);
    }
  });

  it("Split pending confirmation commodity", async function () {
    const weightGram = 1000;
    const commodityType = "pinda";
    expect(
      await commodity
        .connect(farmer)
        .mintCommodity(weightGram, commodityType, warehouse.address)
    );
    await expect(commodity.connect(warehouse).splitCommodity(0, 4)).to.be
      .reverted;
    await expect(
      commodity.connect(warehouse).splitCommodityByList(0, [250, 250, 500])
    ).to.be.reverted;
  });

  it("Split confirmed commodity in 2", async function () {
    const weightGram = 1000;
    const commodityType = "pinda";
    const amountOfSplits = 2;
    expect(
      await commodity
        .connect(farmer)
        .mintCommodity(weightGram, commodityType, warehouse.address)
    );
    expect(
      await commodity.connect(warehouse).confirmCommodity(0, owner.address)
    );
    expect(
      await commodity.connect(warehouse).splitCommodity(0, amountOfSplits)
    );

    await expect(commodity.dataOf(0)).to.be.revertedWith(
      "TradeCoinERC1155: data query for zero address"
    );

    for (i = 0; i < amountOfSplits; i++) {
      // console.log(i);
      expect(await commodity.balanceOf(warehouse.address, i + 1)).to.equal(
        weightGram / amountOfSplits
      );
      expect(await commodity.stateCommodityOf(i + 1)).to.equal(
        commodityState.Confirmed
      );
      expect(await commodity.destinationCommodityOf(i + 1)).to.equal(
        warehouse.address
      );
      expect(await commodity.ownerOf(i + 1)).to.equal(owner.address);
    }
  });

  it("Split confirmed commodity in 5", async function () {
    const weightGram = 1000;
    const commodityType = "pinda";
    const amountOfSplits = 5;
    expect(
      await commodity
        .connect(farmer)
        .mintCommodity(weightGram, commodityType, warehouse.address)
    );
    expect(
      await commodity.connect(warehouse).confirmCommodity(0, owner.address)
    );
    expect(
      await commodity.connect(warehouse).splitCommodity(0, amountOfSplits)
    );

    await expect(commodity.dataOf(0)).to.be.revertedWith(
      "TradeCoinERC1155: data query for zero address"
    );

    for (i = 0; i < amountOfSplits; i++) {
      // console.log(i);
      expect(await commodity.balanceOf(warehouse.address, i + 1)).to.equal(
        weightGram / amountOfSplits
      );
      expect(await commodity.stateCommodityOf(i + 1)).to.equal(
        commodityState.Confirmed
      );
      expect(await commodity.destinationCommodityOf(i + 1)).to.equal(
        warehouse.address
      );
      expect(await commodity.ownerOf(i + 1)).to.equal(owner.address);
    }
  });

  it("Split confirmed commodity by where there is a rest", async function () {
    const weightGram = 1000;
    const commodityType = "pinda";
    const amountOfSplits = 7;
    expect(
      await commodity
        .connect(farmer)
        .mintCommodity(weightGram, commodityType, warehouse.address)
    );
    expect(
      await commodity.connect(warehouse).confirmCommodity(0, owner.address)
    );
    await expect(
      commodity.connect(warehouse).splitCommodity(0, amountOfSplits)
    ).to.be.revertedWith("TradeCoinERC1155: Can not split evenly");
  });

  it("Split confirmed commodity by listOfAmounts of 2", async function () {
    const weightGram = 1000;
    const commodityType = "pinda";
    const splitList = [100, 900];
    expect(
      await commodity
        .connect(farmer)
        .mintCommodity(weightGram, commodityType, warehouse.address)
    );
    expect(
      await commodity.connect(warehouse).confirmCommodity(0, owner.address)
    );
    expect(
      await commodity.connect(warehouse).splitCommodityByList(0, splitList)
    );

    await expect(commodity.dataOf(0)).to.be.revertedWith(
      "TradeCoinERC1155: data query for zero address"
    );

    for (i = 0; i < splitList.length; i++) {
      expect(await commodity.balanceOf(warehouse.address, i + 1)).to.equal(
        splitList[i]
      );
      // console.log(i);
      expect(await commodity.stateCommodityOf(i + 1)).to.equal(
        commodityState.Confirmed
      );
      expect(await commodity.destinationCommodityOf(i + 1)).to.equal(
        warehouse.address
      );
      expect(await commodity.ownerOf(i + 1)).to.equal(owner.address);
    }
  });

  it("Split confirmed commodity by listOfAmounts of 5", async function () {
    const weightGram = 1000;
    const commodityType = "pinda";
    const splitList = [100, 100, 200, 100, 500];
    expect(
      await commodity
        .connect(farmer)
        .mintCommodity(weightGram, commodityType, warehouse.address)
    );
    expect(
      await commodity.connect(warehouse).confirmCommodity(0, owner.address)
    );
    expect(
      await commodity.connect(warehouse).splitCommodityByList(0, splitList)
    );

    await expect(commodity.dataOf(0)).to.be.revertedWith(
      "TradeCoinERC1155: data query for zero address"
    );

    for (i = 0; i < splitList.length; i++) {
      expect(await commodity.balanceOf(warehouse.address, i + 1)).to.equal(
        splitList[i]
      );
      // console.log(i);
      expect(await commodity.stateCommodityOf(i + 1)).to.equal(
        commodityState.Confirmed
      );
      expect(await commodity.destinationCommodityOf(i + 1)).to.equal(
        warehouse.address
      );
      expect(await commodity.ownerOf(i + 1)).to.equal(owner.address);
    }
  });

  it("Split confirmed commodity by listOfAmounts that is not same as balance", async function () {
    const weightGram = 1000;
    const commodityType = "pinda";
    const splitList = [300, 300, 100, 500];
    expect(
      await commodity
        .connect(farmer)
        .mintCommodity(weightGram, commodityType, warehouse.address)
    );
    expect(
      await commodity.connect(warehouse).confirmCommodity(0, owner.address)
    );
    await expect(
      commodity.connect(warehouse).splitCommodityByList(0, splitList)
    ).to.be.revertedWith(
      "TradeCoinERC1155: total weight does not equal total weight of list"
    );
  });

  it("Split confirmed commodity by second warehouse", async function () {
    const approvedWarehouse2 = accounts[9];
    await commodity.grantWarehouseRole(accounts[9].address);
    const weightGram = 1000;
    const commodityType = "pinda";
    const amountOfSplits = 5;
    const splitList = [100, 300, 100, 500];

    expect(
      await commodity
        .connect(farmer)
        .mintCommodity(weightGram, commodityType, warehouse.address)
    );
    expect(
      await commodity.connect(warehouse).confirmCommodity(0, owner.address)
    );
    await expect(
      commodity.connect(approvedWarehouse2).splitCommodity(0, amountOfSplits)
    ).to.be.revertedWith("TradeCoinERC1155: Commodity is not near you");
    await expect(
      commodity.connect(approvedWarehouse2).splitCommodityByList(0, splitList)
    ).to.be.revertedWith("TradeCoinERC1155: Commodity is not near you");
  });

  it("Split commodity in not approved state", async function () {
    const weightGram = 1000;
    const commodityType = "pinda";
    const tokenId = 0;
    const amountOfSplits = 5;
    const splitList = [100, 300, 100, 500];
    expect(
      await commodity
        .connect(farmer)
        .mintCommodity(weightGram, commodityType, warehouse.address)
    );
    expect(
      await commodity
        .connect(warehouse)
        .confirmCommodity(tokenId, owner.address)
    );

    expect(
      await commodity
        .connect(warehouse)
        .createDelivery(tokenId, processor.address, transporter.address)
    );

    await expect(
      commodity.connect(warehouse).splitCommodity(0, amountOfSplits)
    ).to.be.revertedWith(
      "TradeCoinERC1155: Commodity is not in the right state for splitting"
    );
    await expect(
      commodity.connect(warehouse).splitCommodityByList(0, splitList)
    ).to.be.revertedWith(
      "TradeCoinERC1155: Commodity is not in the right state for splitting"
    );
  });

  it("Transporting commodity from warehouse", async function () {
    const weightGram = 1000;
    const commodityType = "pinda";
    const tokenId = 0;
    expect(
      await commodity
        .connect(farmer)
        .mintCommodity(weightGram, commodityType, warehouse.address)
    );
    expect(
      await commodity
        .connect(warehouse)
        .confirmCommodity(tokenId, owner.address)
    );

    expect(
      await commodity
        .connect(warehouse)
        .createDelivery(tokenId, processor.address, transporter.address)
    );
    expect(await commodity.stateCommodityOf(tokenId)).to.equal(
      commodityState.PendingTransport
    );
    expect(await commodity.connect(transporter).pickupCommodity(tokenId));
    expect(await commodity.stateCommodityOf(tokenId)).to.equal(
      commodityState.Transporting
    );
    expect(await commodity.balanceOf(warehouse.address, tokenId)).to.equal(0);
    expect(await commodity.balanceOf(transporter.address, tokenId)).to.equal(
      weightGram
    );

    expect(await commodity.connect(transporter).deliveredCommodity(tokenId));

    expect(await commodity.pickupCommodityOf(tokenId)).to.equal(
      warehouse.address
    );
    // console.log("before commodity");
    expect(await commodity.stateCommodityOf(tokenId)).to.equal(
      commodityState.PendingProcess
    );
    // const state = await commodity.stateCommodityOf(0);
    // console.log("The state is", state);
    expect(await commodity.destinationCommodityOf(tokenId)).to.equal(
      processor.address
    );
    // allAddr();
  });

  it("Transporting commodity from warehouse to processor", async function () {
    const weightGram = 1000;
    const commodityType = "pinda";
    const tokenId = 0;
    expect(
      await commodity
        .connect(farmer)
        .mintCommodity(weightGram, commodityType, warehouse.address)
    );
    expect(
      await commodity
        .connect(warehouse)
        .confirmCommodity(tokenId, owner.address)
    );

    expect(
      await commodity
        .connect(warehouse)
        .createDelivery(tokenId, processor.address, transporter.address)
    );
    expect(await commodity.connect(transporter).pickupCommodity(tokenId));
    expect(await commodity.connect(transporter).deliveredCommodity(tokenId));
    expect(
      await commodity
        .connect(processor)
        .confirmDelivery(tokenId, transporter.address)
    );

    expect(await commodity.balanceOf(processor.address, tokenId)).to.equal(
      weightGram
    );

    expect(await commodity.pickupCommodityOf(tokenId)).to.equal(
      warehouse.address
    );
    // console.log("before commodity");
    expect(await commodity.stateCommodityOf(tokenId)).to.equal(
      commodityState.Processing
    );
    // const state = await commodity.stateCommodityOf(0);
    // console.log("The state is", state);
    expect(await commodity.destinationCommodityOf(tokenId)).to.equal(
      processor.address
    );
    // allAddr();
  });

  it("pickup commodty not set to pending transport", async function () {
    const weightGram = 1000;
    const commodityType = "pinda";
    const tokenId = 0;
    expect(
      await commodity
        .connect(farmer)
        .mintCommodity(weightGram, commodityType, warehouse.address)
    );
    expect(
      await commodity
        .connect(warehouse)
        .confirmCommodity(tokenId, owner.address)
    );

    await expect(
      commodity.connect(transporter).pickupCommodity(tokenId)
    ).to.be.revertedWith(
      "TradeCoinERC1155: this commodity is not set to pending for transport"
    );
  });

  it("deliver commodty not set to pending transport", async function () {
    const weightGram = 1000;
    const commodityType = "pinda";
    const tokenId = 0;
    expect(
      await commodity
        .connect(farmer)
        .mintCommodity(weightGram, commodityType, warehouse.address)
    );
    expect(
      await commodity
        .connect(warehouse)
        .confirmCommodity(tokenId, owner.address)
    );

    await expect(
      commodity.connect(transporter).deliveredCommodity(tokenId)
    ).to.be.revertedWith(
      "TradeCoinERC1155: this commodity is not set to transport"
    );
  });

  it("Confirm already created commodity by warehouse", async function () {
    const weightGram = 1000;
    const commodityType = "pinda";
    const tokenId = 0;
    expect(
      await commodity
        .connect(farmer)
        .mintCommodity(weightGram, commodityType, warehouse.address)
    );
    expect(
      await commodity
        .connect(warehouse)
        .confirmCommodity(tokenId, owner.address)
    );

    expect(
      await commodity
        .connect(warehouse)
        .createDelivery(tokenId, processor.address, transporter.address)
    );
    await expect(
      commodity.connect(warehouse).confirmCommodity(tokenId, owner.address)
    ).to.be.revertedWith("The token is not pending for confirmation");
  });

  it("Confirm delivery before arrival", async function () {
    const weightGram = 1000;
    const commodityType = "pinda";
    const tokenId = 0;
    expect(
      await commodity
        .connect(farmer)
        .mintCommodity(weightGram, commodityType, warehouse.address)
    );
    expect(
      await commodity
        .connect(warehouse)
        .confirmCommodity(tokenId, owner.address)
    );

    expect(
      await commodity
        .connect(warehouse)
        .createDelivery(tokenId, processor.address, transporter.address)
    );

    await expect(
      commodity.connect(processor).confirmDelivery(tokenId, transporter.address)
    ).to.be.revertedWith("The commodity has not yet been delivered");
  });

  it("Transporting commodity from warehouse to processor and to second approved warehouse", async function () {
    const weightGram = 1000;
    const commodityType = "pinda";
    const tokenId = 0;
    const approvedWarehouse2 = accounts[9];
    await commodity
      .connect(owner)
      .grantWarehouseRole(approvedWarehouse2.address);

    expect(
      await commodity
        .connect(farmer)
        .mintCommodity(weightGram, commodityType, warehouse.address)
    );
    expect(
      await commodity
        .connect(warehouse)
        .confirmCommodity(tokenId, owner.address)
    );

    expect(
      await commodity
        .connect(warehouse)
        .createDelivery(tokenId, processor.address, transporter.address)
    );
    expect(await commodity.connect(transporter).pickupCommodity(tokenId));
    expect(await commodity.connect(transporter).deliveredCommodity(tokenId));
    expect(
      await commodity
        .connect(processor)
        .confirmDelivery(tokenId, transporter.address)
    );

    //To approved warehouse
    expect(
      await commodity
        .connect(processor)
        .createDelivery(
          tokenId,
          approvedWarehouse2.address,
          transporter.address
        )
    );
    expect(await commodity.connect(transporter).pickupCommodity(tokenId));
    expect(await commodity.connect(transporter).deliveredCommodity(tokenId));
    expect(
      await commodity
        .connect(approvedWarehouse2)
        .confirmDelivery(tokenId, transporter.address)
    );
    expect(
      await commodity.balanceOf(approvedWarehouse2.address, tokenId)
    ).to.equal(weightGram);
    expect(await commodity.pickupCommodityOf(tokenId)).to.equal(
      processor.address
    );
    expect(await commodity.stateCommodityOf(tokenId)).to.equal(
      commodityState.Stored
    );
    expect(await commodity.destinationCommodityOf(tokenId)).to.equal(
      approvedWarehouse2.address
    );
  });

  it("Transporting commodity from warehouse to processor and adding full processes", async function () {
    const weightGram = 1000;
    const commodityType = "pinda";
    const tokenId = 0;
    const processes = ["wash", "peel", "clean", "salt", "package"];
    expect(
      await commodity
        .connect(farmer)
        .mintCommodity(weightGram, commodityType, warehouse.address)
    );
    expect(
      await commodity
        .connect(warehouse)
        .confirmCommodity(tokenId, owner.address)
    );

    expect(
      await commodity
        .connect(warehouse)
        .createDelivery(tokenId, processor.address, transporter.address)
    );
    expect(await commodity.connect(transporter).pickupCommodity(tokenId));
    expect(await commodity.connect(transporter).deliveredCommodity(tokenId));
    expect(
      await commodity
        .connect(processor)
        .confirmDelivery(tokenId, transporter.address)
    );

    expect(await commodity.balanceOf(processor.address, tokenId)).to.equal(
      weightGram
    );

    expect(await commodity.pickupCommodityOf(tokenId)).to.equal(
      warehouse.address
    );
    // console.log("before commodity");
    expect(await commodity.stateCommodityOf(tokenId)).to.equal(
      commodityState.Processing
    );
    // const state = await commodity.stateCommodityOf(0);
    // console.log("The state is", state);
    expect(await commodity.destinationCommodityOf(tokenId)).to.equal(
      processor.address
    );
    // processes
    expect(await commodity.connect(processor).addProcesses(tokenId, processes));
    // allAddr();
    for (i = 0; i < processes.length; i++) {
      expect(await commodity.isobyIndexOf(tokenId, i)).to.equal(processes[i]);
    }
  });

  it("Transporting commodity from warehouse to processor and appending to list", async function () {
    const weightGram = 1000;
    const commodityType = "pinda";
    const tokenId = 0;
    const processes = ["wash", "peel", "clean", "salt", "package"];
    expect(
      await commodity
        .connect(farmer)
        .mintCommodity(weightGram, commodityType, warehouse.address)
    );
    expect(
      await commodity
        .connect(warehouse)
        .confirmCommodity(tokenId, owner.address)
    );

    expect(
      await commodity
        .connect(warehouse)
        .createDelivery(tokenId, processor.address, transporter.address)
    );
    expect(await commodity.connect(transporter).pickupCommodity(tokenId));
    expect(await commodity.connect(transporter).deliveredCommodity(tokenId));
    expect(
      await commodity
        .connect(processor)
        .confirmDelivery(tokenId, transporter.address)
    );

    expect(await commodity.balanceOf(processor.address, tokenId)).to.equal(
      weightGram
    );

    expect(await commodity.pickupCommodityOf(tokenId)).to.equal(
      warehouse.address
    );
    expect(await commodity.stateCommodityOf(tokenId)).to.equal(
      commodityState.Processing
    );
    expect(await commodity.destinationCommodityOf(tokenId)).to.equal(
      processor.address
    );
    for (i = 0; i < processes.length; i++) {
      expect(
        await commodity.connect(processor).addProcesses(tokenId, [processes[i]])
      );
    }
    for (j = 0; j < processes.length; j++) {
      expect(await commodity.isobyIndexOf(tokenId, j)).to.equal(processes[j]);
    }
  });

  it("Transporting commodity from warehouse to processor and changing full list", async function () {
    const weightGram = 1000;
    const commodityType = "pinda";
    const tokenId = 0;
    const processes = ["wash", "peel", "clean", "salt", "package"];
    expect(
      await commodity
        .connect(farmer)
        .mintCommodity(weightGram, commodityType, warehouse.address)
    );
    expect(
      await commodity
        .connect(warehouse)
        .confirmCommodity(tokenId, owner.address)
    );

    expect(
      await commodity
        .connect(warehouse)
        .createDelivery(tokenId, processor.address, transporter.address)
    );
    expect(await commodity.connect(transporter).pickupCommodity(tokenId));
    expect(await commodity.connect(transporter).deliveredCommodity(tokenId));
    expect(
      await commodity
        .connect(processor)
        .confirmDelivery(tokenId, transporter.address)
    );

    expect(await commodity.balanceOf(processor.address, tokenId)).to.equal(
      weightGram
    );

    expect(await commodity.pickupCommodityOf(tokenId)).to.equal(
      warehouse.address
    );
    expect(await commodity.stateCommodityOf(tokenId)).to.equal(
      commodityState.Processing
    );
    expect(await commodity.destinationCommodityOf(tokenId)).to.equal(
      processor.address
    );
    for (i = 0; i < processes.length; i++) {
      processesSliced = processes.slice(0, processes.length + 1 - i);
      expect(
        await commodity
          .connect(processor)
          .changeFullProcessesList(tokenId, processesSliced)
      );
      for (j = 0; j < processesSliced.length; j++) {
        expect(await commodity.isobyIndexOf(tokenId, j)).to.equal(
          processesSliced[j]
        );
      }
    }
  });

  it("Processor adding processes to tranporting commodity", async function () {
    const weightGram = 1000;
    const commodityType = "pinda";
    const tokenId = 0;
    const processes = ["wash", "peel", "clean", "salt", "package"];
    expect(
      await commodity
        .connect(farmer)
        .mintCommodity(weightGram, commodityType, warehouse.address)
    );
    expect(
      await commodity
        .connect(warehouse)
        .confirmCommodity(tokenId, owner.address)
    );

    expect(
      await commodity
        .connect(warehouse)
        .createDelivery(tokenId, processor.address, transporter.address)
    );
    expect(await commodity.connect(transporter).pickupCommodity(tokenId));
    expect(await commodity.connect(transporter).deliveredCommodity(tokenId));

    await expect(
      commodity.connect(processor).addProcesses(tokenId, processes)
    ).to.be.revertedWith("TradeCoinERC1155: is not set to processing");
  });

  it("Processor changing full processes list while commodity transporting", async function () {
    const weightGram = 1000;
    const commodityType = "pinda";
    const tokenId = 0;
    const processes = ["wash", "peel", "clean", "salt", "package"];
    expect(
      await commodity
        .connect(farmer)
        .mintCommodity(weightGram, commodityType, warehouse.address)
    );
    expect(
      await commodity
        .connect(warehouse)
        .confirmCommodity(tokenId, owner.address)
    );

    expect(
      await commodity
        .connect(warehouse)
        .createDelivery(tokenId, processor.address, transporter.address)
    );
    expect(await commodity.connect(transporter).pickupCommodity(tokenId));
    expect(await commodity.connect(transporter).deliveredCommodity(tokenId));

    await expect(
      commodity.connect(processor).changeFullProcessesList(tokenId, processes)
    ).to.be.revertedWith("TradeCoinERC1155: is not set to processing");
  });

  it("Decrease weight", async function () {
    const weightGram = 1000;
    const commodityType = "pinda";
    const tokenId = 0;
    const amountInGram = 100;
    expect(
      await commodity
        .connect(farmer)
        .mintCommodity(weightGram, commodityType, warehouse.address)
    );
    expect(
      await commodity
        .connect(warehouse)
        .confirmCommodity(tokenId, owner.address)
    );

    expect(
      await commodity
        .connect(warehouse)
        .createDelivery(tokenId, processor.address, transporter.address)
    );
    expect(await commodity.connect(transporter).pickupCommodity(tokenId));
    expect(await commodity.connect(transporter).deliveredCommodity(tokenId));
    expect(
      await commodity
        .connect(processor)
        .confirmDelivery(tokenId, transporter.address)
    );

    expect(
      await commodity.connect(processor).decreaseWeight(tokenId, amountInGram)
    );

    expect(await commodity.balanceOf(processor.address, tokenId)).to.equal(
      weightGram - amountInGram
    );
  });

  it("Decrease weight while not in possesion by processor", async function () {
    const weightGram = 1000;
    const commodityType = "pinda";
    const tokenId = 0;
    const amountInGram = 100;
    expect(
      await commodity
        .connect(farmer)
        .mintCommodity(weightGram, commodityType, warehouse.address)
    );
    expect(
      await commodity
        .connect(warehouse)
        .confirmCommodity(tokenId, owner.address)
    );

    expect(
      await commodity
        .connect(warehouse)
        .createDelivery(tokenId, processor.address, transporter.address)
    );
    expect(await commodity.connect(transporter).pickupCommodity(tokenId));
    expect(await commodity.connect(transporter).deliveredCommodity(tokenId));

    await expect(
      commodity.connect(processor).decreaseWeight(tokenId, amountInGram)
    ).to.be.reverted;
  });

  it("Second Processor changing full processes list to commodity not near him", async function () {
    const approvedProcessor2 = accounts[9];
    await commodity
      .connect(owner)
      .grantProcessorRole(approvedProcessor2.address);

    const weightGram = 1000;
    const commodityType = "pinda";
    const tokenId = 0;
    const processes = ["wash", "peel", "clean", "salt", "package"];
    expect(
      await commodity
        .connect(farmer)
        .mintCommodity(weightGram, commodityType, warehouse.address)
    );
    expect(
      await commodity
        .connect(warehouse)
        .confirmCommodity(tokenId, owner.address)
    );

    expect(
      await commodity
        .connect(warehouse)
        .createDelivery(tokenId, processor.address, transporter.address)
    );
    expect(await commodity.connect(transporter).pickupCommodity(tokenId));
    expect(await commodity.connect(transporter).deliveredCommodity(tokenId));
    expect(
      await commodity
        .connect(processor)
        .confirmDelivery(tokenId, transporter.address)
    );

    await expect(
      commodity.connect(approvedProcessor2).addProcesses(tokenId, processes)
    ).to.be.revertedWith(
      "TradeCoinERC1155: this commodity is not at your address"
    );
  });

  it("Second Processor adding processes to commodity not near him", async function () {
    const approvedProcessor2 = accounts[9];
    await commodity
      .connect(owner)
      .grantProcessorRole(approvedProcessor2.address);

    const weightGram = 1000;
    const commodityType = "pinda";
    const tokenId = 0;
    const processes = ["wash", "peel", "clean", "salt", "package"];
    expect(
      await commodity
        .connect(farmer)
        .mintCommodity(weightGram, commodityType, warehouse.address)
    );
    expect(
      await commodity
        .connect(warehouse)
        .confirmCommodity(tokenId, owner.address)
    );

    expect(
      await commodity
        .connect(warehouse)
        .createDelivery(tokenId, processor.address, transporter.address)
    );
    expect(await commodity.connect(transporter).pickupCommodity(tokenId));
    expect(await commodity.connect(transporter).deliveredCommodity(tokenId));
    expect(
      await commodity
        .connect(processor)
        .confirmDelivery(tokenId, transporter.address)
    );

    await expect(
      commodity
        .connect(approvedProcessor2)
        .changeFullProcessesList(tokenId, processes)
    ).to.be.revertedWith(
      "TradeCoinERC1155: this commodity is not at your address"
    );
  });

  it("Create delivery by unapproved address", async function () {
    await expect(commodity.connect(notApproved).createDelivery(0)).to.be
      .reverted;
  });

  it("Pickup commodity by unapproved address", async function () {
    await expect(commodity.connect(notApproved).pickupCommodity(0)).to.be
      .reverted;
  });

  it("deliver commodity by unapproved address", async function () {
    await expect(commodity.connect(notApproved).deliveredCommodity(0)).to.be
      .reverted;
  });

  it("Confirm delivery by unapproved address", async function () {
    await expect(
      commodity.connect(notApproved).confirmDelivery(0, transporter.address)
    ).to.be.reverted;
  });

  it("Add processes by unapproved address", async function () {
    await expect(
      commodity.connect(notApproved).addProcesses(0, ["peel", "wash"])
    ).to.be.reverted;
  });

  it("Change processes by unapproved address", async function () {
    await expect(
      commodity
        .connect(notApproved)
        .changeFullProcessesList(0, ["peel", "wash"])
    ).to.be.reverted;
  });

  it("Split commodity by unapproved address", async function () {
    await expect(
      commodity.connect(notApproved).splitCommodityByList(0, [500, 300, 50, 50])
    ).to.be.reverted;
    await expect(commodity.connect(notApproved).splitCommodity(0, 5)).to.be
      .reverted;
  });

  it("Grant Role by non owner", async function () {
    await expect(
      commodity.connect(notApproved).grantAllRolesForOwner(owner.address)
    ).to.be.reverted;
    await expect(commodity.connect(notApproved).grantFarmerRole(farmer.address))
      .to.be.reverted;
    await expect(
      commodity.connect(notApproved).grantWarehouseRole(warehouse.address)
    ).to.be.reverted;
    await expect(
      commodity.connect(notApproved).grantTransporterRole(transporter.address)
    ).to.be.reverted;
    await expect(
      commodity.connect(notApproved).grantProcessorRole(processor.address)
    ).to.be.reverted;
  });
});
