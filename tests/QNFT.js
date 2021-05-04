const chai = require("chai");
const { solidity } = require("ethereum-waffle");
const { ethers } = require("hardhat");

const { expect } = chai;

chai.use(solidity);

const units = (value) => ethers.utils.parseUnits(value.toString());
const days = (value) => value * 24 * 60 * 60;
const weeks = (value) => days(value * 7);
const months = (value) => days(value * 30);
const years = (value) => days(value * 365);

const nftImages = {
  A: ["A1", "A2", "A3", "A4", "A5"],
  B: ["B1", "B2", "B3", "B4", "B5"],
  C: ["C1", "C2", "C3", "C4", "C5"],
  D: ["D1", "D2", "D3", "D4", "D5"],
};

describe("Tests", () => {
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

  describe("QNFTSettings: owner can manager nft/mint options", () => {
    it("Should be ble to set mint price multiplier", async () => {
      await expect(
        qnftSettings.connect(user).setMintPriceMultiplier(200)
      ).to.be.revertedWith("Ownable: caller is not the owner");

      expect(await qnftSettings.callStatic.mintPriceMultiplier()).to.be.equal(
        100
      );
      await qnftSettings.setMintPriceMultiplier(200);
      expect(await qnftSettings.callStatic.mintPriceMultiplier()).to.be.equal(
        200
      );
      await qnftSettings.setMintPriceMultiplier(100);
      expect(await qnftSettings.callStatic.mintPriceMultiplier()).to.be.equal(
        100
      );
    });

    it("Should be able to add/remove mint options", async () => {
      await expect(
        qnftSettings
          .connect(user)
          .addMintOption(units(0), units(1000), months(1), 20)
      ).to.be.revertedWith("Ownable: caller is not the owner");

      expect(await qnftSettings.callStatic.mintOptionsCount()).to.be.equal(0);
      await qnftSettings.addMintOption(units(0), units(0), weeks(1), 0); // 100 qstk, 1 months duration, 20% discount
      await qnftSettings.addMintOption(units(0), units(200), months(2), 30); // 200 qstk, 2 months duration, 30% discount
      await qnftSettings.addMintOption(units(0), units(300), months(3), 40); // 300 qstk, 3 months duration, 40% discount
      await qnftSettings.addMintOption(units(0), units(100), months(1), 20); // 100 qstk, 1 months duration, 20% discount
      expect(await qnftSettings.callStatic.mintOptionsCount()).to.be.equal(4);

      await expect(
        qnftSettings.connect(user).removeMintOption(4)
      ).to.be.revertedWith("Ownable: caller is not the owner");
      await expect(qnftSettings.removeMintOption(4)).to.be.revertedWith(
        "QNFTSettings: invalid mint option id"
      );

      await qnftSettings.removeMintOption(0);
      expect(await qnftSettings.callStatic.mintOptionsCount()).to.be.equal(3);

      expect((await qnftSettings.mintOptions(0))[0]).equal(units(0));
      expect((await qnftSettings.mintOptions(0))[1]).equal(units(100));
      expect((await qnftSettings.mintOptions(1))[2]).equal(months(2));
      expect((await qnftSettings.mintOptions(2))[3]).equal(40);
    });

    it("Should be able to add/remove nft images", async () => {
      await expect(
        qnftSettings.connect(user).addImageSet(units(0.1), nftImages.D)
      ).to.be.revertedWith("Ownable: caller is not the owner");

      await expect(
        qnftSettings.addImageSet(units(0.1), [...nftImages.D, "invalid"])
      ).to.be.revertedWith("QNFTSettings: image length does not match");

      expect(await qnftSettings.callStatic.nftImagesCount()).to.be.equal(0);
      await qnftSettings.addImageSet(units(0.1), nftImages.D);
      await qnftSettings.addImageSet(units(0.2), nftImages.B);
      await qnftSettings.addImageSet(units(0.3), nftImages.C);
      await qnftSettings.addImageSet(units(0.1), nftImages.A);
      expect(await qnftSettings.callStatic.nftImagesCount()).to.be.equal(4);

      await expect(
        qnftSettings.connect(user).removeImageSet(4)
      ).to.be.revertedWith("Ownable: caller is not the owner");
      await expect(qnftSettings.removeImageSet(4)).to.be.revertedWith(
        "QNFTSettings: invalid id"
      );

      await qnftSettings.removeImageSet(0);
      expect(await qnftSettings.callStatic.nftImagesCount()).to.be.equal(3);

      expect((await qnftSettings.nftImages(0))[0]).equal(units(0.1));
      expect((await qnftSettings.nftImages(1))[1]).equal(nftImages.B[0]);
      expect((await qnftSettings.nftImages(1))[2]).equal(nftImages.B[1]);
      expect((await qnftSettings.nftImages(1))[3]).equal(nftImages.B[2]);
      expect((await qnftSettings.nftImages(1))[4]).equal(nftImages.B[3]);
      expect((await qnftSettings.nftImages(1))[5]).equal(nftImages.B[4]);
    });
  });
});
