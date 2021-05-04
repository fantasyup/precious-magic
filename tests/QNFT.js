const chai = require("chai");
const { solidity } = require("ethereum-waffle");
const { ethers } = require("hardhat");

const { expect } = chai;

chai.use(solidity);

const units = (value) => ethers.utils.parseUnits(value.toString());

describe("QNFT", () => {
  let qstk, qnft, qnftSettings;
  let deployer, foundation, user;

  before(async () => {
    const accounts = await ethers.getSigners();
    deployer = accounts[0];
    foundation = accounts[1];
    user = accounts[2];

    const QStkFactory = await ethers.getContractFactory("QStk");
    qstk = await QStkFactory.deploy(units(300000000));
    await qstk.deployed();

    const QNFTSettingsFactory = await ethers.getContractFactory("QNFTSettings");
    qnftSettings = await QNFTSettingsFactory.deploy();
    await qnftSettings.deployed();

    const QNFTFactory = await ethers.getContractFactory("QNFT");
    qnft = await QNFTFactory.deploy(
      qstk.address,
      qnftSettings.address,
      foundation.address
    );
    await qnft.deployed();

    await qnftSettings.setQNft(qnft.address);
  });

  describe("QNFT: owner can manage qstk balance", () => {
    it("Only owner can manager qstk balance", async () => {
      await expect(
        qnft.connect(user).depositQstk(units(10))
      ).to.be.revertedWith("Ownable: caller is not the owner");
      await expect(
        qnft.connect(user).withdrawQstk(units(10))
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Should be able to deposit qstk", async () => {
      await expect(qnft.depositQstk(units(10))).to.be.revertedWith(
        "ERC20: transfer amount exceeds allowance"
      );

      expect(await qnft.callStatic.totalQstkBalance()).to.be.equal(0);
      expect(await qnft.callStatic.remainingQstk()).to.be.equal(0);

      await qstk.approve(qnft.address, units(110000000));
      await qnft.depositQstk(units(110000000));

      expect(await qnft.callStatic.totalQstkBalance()).to.be.equal(
        units(110000000)
      );
      expect(await qnft.callStatic.remainingQstk()).to.be.equal(
        units(110000000)
      );
    });

    it("Should be able to withdraw qstk", async () => {
      expect(await qnft.callStatic.totalQstkBalance()).to.be.equal(
        units(110000000)
      );
      expect(await qnft.callStatic.remainingQstk()).to.be.equal(
        units(110000000)
      );

      await expect(qnft.withdrawQstk(units(200000000))).to.be.revertedWith(
        "QNFT: not enough balance"
      );

      await qnft.withdrawQstk(units(10000000));

      expect(await qnft.callStatic.totalQstkBalance()).to.be.equal(
        units(100000000)
      );
      expect(await qnft.callStatic.remainingQstk()).to.be.equal(
        units(100000000)
      );
    });
  });
});
