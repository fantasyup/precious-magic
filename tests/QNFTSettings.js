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

const bgImages = {
  A: ["A1", "A2", "A3", "A4"],
  B: ["B1", "B2", "B3", "B4"],
  C: ["C1", "C2", "C3", "C4"],
  D: ["D1", "D2", "D3", "D4"],
};

const favCoins = {
  A: {
    mintPrice: units(0.01),
    name: "A",
    symbol: "A-symbol",
    icon: "A-icon",
    website: "A-website",
    social: "A-social",
    erc20: "0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf",
    other: "A-other",
  },
  B: {
    mintPrice: units(0.02),
    name: "B",
    symbol: "B-symbol",
    icon: "B-icon",
    website: "B-website",
    social: "B-social",
    erc20: "0x2B5AD5c4795c026514f8317c7a215E218DcCD6cF",
    other: "B-other",
  },
  C: {
    mintPrice: units(0.03),
    name: "C",
    symbol: "C-symbol",
    icon: "C-icon",
    website: "C-website",
    social: "C-social",
    erc20: "0x6813Eb9362372EEF6200f3b1dbC3f819671cBA69",
    other: "C-other",
  },
  D: {
    mintPrice: units(0.04),
    name: "D",
    symbol: "D-symbol",
    icon: "D-icon",
    website: "D-website",
    social: "D-social",
    erc20: "0x1efF47bc3a10a45D4B230B5d10E37751FE6AA718",
    other: "D-other",
  },
};

describe("QNFTSettings", () => {
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

    it("Should be able to add/remove background images", async () => {
      await expect(
        qnftSettings.connect(user).addBgImage(bgImages.D)
      ).to.be.revertedWith("Ownable: caller is not the owner");

      await expect(
        qnftSettings.addBgImage([...nftImages.D, "invalid"])
      ).to.be.revertedWith(
        "QNFTSettings: background image length does not match"
      );

      expect(await qnftSettings.callStatic.bgImagesCount()).to.be.equal(0);
      await qnftSettings.addBgImage(bgImages.D);
      await qnftSettings.addBgImage(bgImages.B);
      await qnftSettings.addBgImage(bgImages.C);
      await qnftSettings.addBgImage(bgImages.A);
      expect(await qnftSettings.callStatic.bgImagesCount()).to.be.equal(4);

      await expect(
        qnftSettings.connect(user).removeBgImage(4)
      ).to.be.revertedWith("Ownable: caller is not the owner");
      await expect(qnftSettings.removeBgImage(4)).to.be.revertedWith(
        "QNFTSettings: invalid id"
      );

      await qnftSettings.removeBgImage(0);
      expect(await qnftSettings.callStatic.bgImagesCount()).to.be.equal(3);

      expect((await qnftSettings.bgImages(1))[0]).equal(bgImages.B[0]);
      expect((await qnftSettings.bgImages(1))[1]).equal(bgImages.B[1]);
      expect((await qnftSettings.bgImages(1))[2]).equal(bgImages.B[2]);
      expect((await qnftSettings.bgImages(1))[3]).equal(bgImages.B[3]);
    });

    it("Should be able to add/remove fav coins", async () => {
      await expect(
        qnftSettings.connect(user).addFavCoin(...Object.values(favCoins.A))
      ).to.be.revertedWith("Ownable: caller is not the owner");

      expect(await qnftSettings.callStatic.favCoinsCount()).to.be.equal(0);
      await qnftSettings.addFavCoin(...Object.values(favCoins.A));
      await qnftSettings.addFavCoin(...Object.values(favCoins.B));
      await qnftSettings.addFavCoin(...Object.values(favCoins.C));
      await qnftSettings.addFavCoin(...Object.values(favCoins.D));
      expect(await qnftSettings.callStatic.favCoinsCount()).to.be.equal(4);

      await expect(
        qnftSettings.connect(user).removeFavCoin("invalid")
      ).to.be.revertedWith("Ownable: caller is not the owner");
      await expect(qnftSettings.removeFavCoin("invalid")).to.be.revertedWith(
        "QNFTSettings: favcoin not exists"
      );

      await qnftSettings.removeFavCoin(favCoins.D.name);
      expect(await qnftSettings.callStatic.favCoinsCount()).to.be.equal(3);

      await expect(qnftSettings.favCoinFromName("invalid")).to.be.revertedWith(
        "QNFTSettings: favcoin not exists"
      );

      expect((await qnftSettings.favCoinFromName(favCoins.C.name))[0]).equal(
        favCoins.C.mintPrice
      );
      expect((await qnftSettings.favCoinFromName(favCoins.C.name))[1]).equal(
        favCoins.C.name
      );
      expect((await qnftSettings.favCoinFromName(favCoins.C.name))[2]).equal(
        favCoins.C.symbol
      );
      expect((await qnftSettings.favCoinFromName(favCoins.C.name))[3]).equal(
        favCoins.C.icon
      );
      expect((await qnftSettings.favCoinFromName(favCoins.C.name))[4]).equal(
        favCoins.C.website
      );
      expect((await qnftSettings.favCoinFromName(favCoins.C.name))[5]).equal(
        favCoins.C.social
      );
      expect((await qnftSettings.favCoinFromName(favCoins.C.name))[6]).equal(
        favCoins.C.erc20
      );
      expect((await qnftSettings.favCoinFromName(favCoins.C.name))[7]).equal(
        favCoins.C.other
      );
    });
  });
});
