const chai = require("chai");
const { solidity } = require("ethereum-waffle");
const { ethers } = require("hardhat");

const { expect } = chai;

chai.use(solidity);

describe("QNFT", () => {
  let qstk, qnft;
  let deployer, foundation, user;

  before(async () => {
    const accounts = await ethers.getSigners();
    deployer = accounts[0];
    foundation = accounts[1];
    user = accounts[2];

    const QStkFactory = await ethers.getContractFactory("QStk");
    qstk = await QStkFactory.deploy(ethers.utils.parseUnits("10000000"));
    await qstk.deployed();

    const QNFTFactory = await ethers.getContractFactory("QNFT");
    qnft = await QNFTFactory.deploy(qstk.address, foundation.address);
    await qnft.deployed();
  });

  describe("QNFT: owner can manage qstk balance", () => {
    it("Only owner can manager qstk balance", async () => {
      await expect(
        qnft.connect(user).depositQstk(ethers.utils.parseUnits("10"))
      ).to.be.revertedWith("Ownable: caller is not the owner");
      await expect(
        qnft.connect(user).withdrawQstk(ethers.utils.parseUnits("10"))
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should be able to deposit qstk", async () => {
      await expect(
        qnft.depositQstk(ethers.utils.parseUnits("10"))
      ).to.be.revertedWith("ERC20: transfer amount exceeds allowance");

      expect(await qnft.callStatic.totalQstkBalance()).to.be.equal(0);
      expect(await qnft.callStatic.remainingQstk()).to.be.equal(0);

      await qstk.approve(qnft.address, ethers.utils.parseUnits("10"));
      await qnft.depositQstk(ethers.utils.parseUnits("10"));

      expect(await qnft.callStatic.totalQstkBalance()).to.be.equal(
        ethers.utils.parseUnits("10")
      );
      expect(await qnft.callStatic.remainingQstk()).to.be.equal(
        ethers.utils.parseUnits("10")
      );
    });
  });
});
