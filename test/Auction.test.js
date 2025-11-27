const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("SimpleAuction", function () {
  let auction, owner, bidder1, bidder2;

  beforeEach(async () => {
    [owner, bidder1, bidder2] = await ethers.getSigners();
    const SimpleAuction = await ethers.getContractFactory("SimpleAuction");
    auction = await SimpleAuction.deploy();
    await auction.waitForDeployment();
  });

  it("creates auction", async () => {
    const tx = await auction
      .connect(owner)
      .createAuction("Item", ethers.parseEther("1"), 3600);
    const receipt = await tx.wait();
    const id = await auction.auctionCount();
    const res = await auction.getAuction(id);
    expect(res[0]).to.equal(owner.address);
    expect(res[1]).to.equal(ethers.parseEther("1"));
    expect(res[6]).to.equal("Item");
  });

  it("places bids and refunds previous", async () => {
    await auction.createAuction("Item", ethers.parseEther("1"), 3600);
    const id = await auction.auctionCount();

    await expect(
      auction.connect(bidder1).placeBid(id, { value: ethers.parseEther("1.2") })
    ).to.emit(auction, "BidPlaced");

    const balBefore = await ethers.provider.getBalance(bidder1.address);
    await expect(
      auction.connect(bidder2).placeBid(id, { value: ethers.parseEther("1.3") })
    ).to.emit(auction, "BidRefunded");
    const balAfter = await ethers.provider.getBalance(bidder1.address);
    expect(balAfter).to.be.gt(balBefore);
  });

  it("extends time in last 5 minutes", async () => {
    await auction.createAuction("Item", ethers.parseEther("1"), 300);
    const id = await auction.auctionCount();
    await time.increase(280);
    const before = (await auction.getAuction(id))[4];
    await expect(
      auction.connect(bidder1).placeBid(id, { value: ethers.parseEther("1.5") })
    ).to.emit(auction, "TimeExtended");
    const after = (await auction.getAuction(id))[4];
    expect(after).to.be.gt(before);
  });

  it("ends auction and pays seller", async () => {
    await auction.createAuction("Item", ethers.parseEther("1"), 400);
    const id = await auction.auctionCount();
    await auction
      .connect(bidder1)
      .placeBid(id, { value: ethers.parseEther("1.5") });
    const balBefore = await ethers.provider.getBalance(owner.address);
    await time.increase(401);
    await auction.connect(owner).endAuction(id);
    await auction.connect(owner).claimFunds(id);
    const balAfter = await ethers.provider.getBalance(owner.address);
    expect(balAfter).to.be.gt(balBefore);
  });
});
