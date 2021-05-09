const chai = require("chai");
const { solidity } = require("ethereum-waffle");
const { ethers } = require("hardhat");
const { expect } = chai;
const {
  lockOptions,
  favCoins,
  nftImages,
  bgImages,
  units,
  days,
  weeks,
  months,
  years,
} = require("./utils");

chai.use(solidity);

describe("QNFTSettings", () => {
  let qstk, qnft, qnftSettings, qnftGov;
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

    const QNFTGovFactory = await ethers.getContractFactory("QNFTGov");
    qnftGov = await QNFTGovFactory.deploy();
    await qnftGov.deployed();

    const QNFTFactory = await ethers.getContractFactory("QNFT");
    qnft = await QNFTFactory.deploy(
      qstk.address,
      qnftSettings.address,
      qnftGov.address,
      foundation.address
    );
    await qnft.deployed();
  });

  describe("QNFTSettings: owner can set QNFT", () => {
    it("Should be able to set QNFT", async () => {
      await expect(
        qnftSettings.connect(user).setQNft(qnft.address)
      ).to.be.revertedWith("Ownable: caller is not the owner");

      await qnftSettings.setQNft(qnft.address);

      await expect(qnftSettings.setQNft(qnft.address)).to.be.revertedWith(
        "QNFTSettings: QNFT already set"
      );
    });
  });

  describe("QNFTSettings: owner can manager nft/lock options", () => {
    it("Should be ble to set mint price multiplier", async () => {
      await expect(
        qnftSettings.connect(user).setNonTokenPriceMultiplier(200)
      ).to.be.revertedWith("Ownable: caller is not the owner");

      expect(
        await qnftSettings.callStatic.nonTokenPriceMultiplier()
      ).to.be.equal(100);
      await qnftSettings.setNonTokenPriceMultiplier(200);
      expect(
        await qnftSettings.callStatic.nonTokenPriceMultiplier()
      ).to.be.equal(200);
      await qnftSettings.setNonTokenPriceMultiplier(100);
      expect(
        await qnftSettings.callStatic.nonTokenPriceMultiplier()
      ).to.be.equal(100);
    });

    it("Should be able to add/remove lock options", async () => {
      await expect(
        qnftSettings
          .connect(user)
          .addLockOption(units(0), units(1000), months(1), 20)
      ).to.be.revertedWith("Ownable: caller is not the owner");
      await expect(
        qnftSettings.addLockOption(units(0), units(1000), months(1), 101)
      ).to.be.revertedWith("QNFTSettings: invalid discount");

      expect(await qnftSettings.callStatic.lockOptionsCount()).to.be.equal(0);
      await qnftSettings.addLockOption(...Object.values(lockOptions.D));
      await qnftSettings.addLockOption(...Object.values(lockOptions.B));
      await qnftSettings.addLockOption(...Object.values(lockOptions.C));
      await qnftSettings.addLockOption(...Object.values(lockOptions.A));
      expect(await qnftSettings.callStatic.lockOptionsCount()).to.be.equal(4);

      await expect(
        qnftSettings.connect(user).removeLockOption(4)
      ).to.be.revertedWith("Ownable: caller is not the owner");
      await expect(qnftSettings.removeLockOption(4)).to.be.revertedWith(
        "QNFTSettings: invalid lock option id"
      );

      await qnftSettings.removeLockOption(0);
      expect(await qnftSettings.callStatic.lockOptionsCount()).to.be.equal(3);

      expect((await qnftSettings.lockOptions(0))[0]).equal(
        lockOptions.A.minAmount
      );
      expect((await qnftSettings.lockOptions(0))[1]).equal(
        lockOptions.A.maxAmount
      );
      expect((await qnftSettings.lockOptions(1))[2]).equal(
        lockOptions.B.lockDuration
      );
      expect((await qnftSettings.lockOptions(2))[3]).equal(
        lockOptions.C.discount
      );
      await expect(qnftSettings.lockOptionLockDuration(4)).to.be.revertedWith(
        "QNFTSettings: invalid lock option"
      );
      expect(await qnftSettings.lockOptionLockDuration(0)).to.be.equal(
        lockOptions.A.lockDuration
      );
    });

    it("Should be able to add/remove nft images", async () => {
      await expect(
        qnftSettings.connect(user).addImageSet(...Object.values(nftImages.D))
      ).to.be.revertedWith("Ownable: caller is not the owner");

      await expect(
        qnftSettings.addImageSet(
          units(0.1),
          [...nftImages.D.urls, "invalid"],
          nftImages.D.designer_name,
          nftImages.D.designer_wallet,
          nftImages.D.designer_meta
        )
      ).to.be.revertedWith("QNFTSettings: image length does not match");

      expect(await qnftSettings.callStatic.nftImagesCount()).to.be.equal(0);
      await qnftSettings.addImageSet(...Object.values(nftImages.D));
      await qnftSettings.addImageSet(...Object.values(nftImages.B));
      await qnftSettings.addImageSet(...Object.values(nftImages.C));
      await qnftSettings.addImageSet(...Object.values(nftImages.A));
      expect(await qnftSettings.callStatic.nftImagesCount()).to.be.equal(4);

      await expect(
        qnftSettings.connect(user).removeImageSet(4)
      ).to.be.revertedWith("Ownable: caller is not the owner");
      await expect(qnftSettings.removeImageSet(4)).to.be.revertedWith(
        "QNFTSettings: invalid id"
      );

      await qnftSettings.removeImageSet(0);
      expect(await qnftSettings.callStatic.nftImagesCount()).to.be.equal(3);

      expect((await qnftSettings.nftImages(0))[0]).equal(nftImages.A.mintPrice);
      expect((await qnftSettings.nftImages(1))[1]).equal(nftImages.B.urls[0]);
      expect((await qnftSettings.nftImages(1))[2]).equal(nftImages.B.urls[1]);
      expect((await qnftSettings.nftImages(1))[3]).equal(nftImages.B.urls[2]);
      expect((await qnftSettings.nftImages(1))[4]).equal(nftImages.B.urls[3]);
      expect((await qnftSettings.nftImages(1))[5]).equal(nftImages.B.urls[4]);

      await expect(qnftSettings.nftImageMintPrice(4)).to.be.revertedWith(
        "QNFTSettings: invalid image id"
      );
      expect(await qnftSettings.nftImageMintPrice(0)).to.be.equal(
        nftImages.A.mintPrice
      );
    });

    it("Should be able to add/remove background images", async () => {
      await expect(
        qnftSettings.connect(user).addBgImage(bgImages.D)
      ).to.be.revertedWith("Ownable: caller is not the owner");

      await expect(
        qnftSettings.addBgImage([...bgImages.D, "invalid"])
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

      expect(await qnftSettings.callStatic.isFavCoin(favCoins.A.name)).to.be
        .true;
      expect(await qnftSettings.callStatic.isFavCoin(favCoins.D.name)).to.be
        .false;

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

      await expect(qnftSettings.favCoinMintPrice(4)).to.be.revertedWith(
        "QNFTSettings: invalid favcoin id"
      );
      expect(await qnftSettings.favCoinMintPrice(0)).to.be.equal(
        favCoins.A.mintPrice
      );
    });

    it("Should be able to calculate mint price", async () => {
      await expect(
        qnftSettings.callStatic.calcMintPrice(4, 0, 0, 0, units(50), units(10))
      ).to.be.revertedWith("QNFTSettings: invalid image option");
      await expect(
        qnftSettings.callStatic.calcMintPrice(0, 4, 0, 0, units(50), units(10))
      ).to.be.revertedWith("QNFTSettings: invalid background option");
      await expect(
        qnftSettings.callStatic.calcMintPrice(0, 0, 4, 0, units(50), units(10))
      ).to.be.revertedWith("QNFTSettings: invalid fav coin");
      await expect(
        qnftSettings.callStatic.calcMintPrice(0, 0, 0, 4, units(50), units(10))
      ).to.be.revertedWith("QNFTSettings: invalid lock option");
      await expect(
        qnftSettings.callStatic.calcMintPrice(0, 0, 0, 0, units(150), units(10))
      ).to.be.revertedWith("QNFTSettings: invalid mint amount");
      await expect(
        qnftSettings.callStatic.calcMintPrice(0, 0, 0, 1, units(50), units(10))
      ).to.be.revertedWith("QNFTSettings: invalid mint amount");

      expect(
        await qnftSettings.callStatic.calcMintPrice(
          0,
          0,
          0,
          0,
          units(50),
          units(10)
        )
      ).to.be.equal(units(0.1104));

      await expect(
        qnftSettings.connect(user).setTokenPriceMultiplier(30)
      ).to.be.revertedWith("Ownable: caller is not the owner");

      await qnftSettings.setTokenPriceMultiplier(300);

      expect(
        await qnftSettings.callStatic.calcMintPrice(
          0,
          0,
          0,
          0,
          units(50),
          units(20)
        )
      ).to.be.equal(units(0.1112));

      await qnftSettings.setTokenPriceMultiplier(900);
      await qnftSettings.setNonTokenPriceMultiplier(200);

      expect(
        await qnftSettings.callStatic.calcMintPrice(
          0,
          0,
          0,
          0,
          units(50),
          units(20)
        )
      ).to.be.equal(units(0.2236));
    });
  });
  describe("QNFTSettings: not able to remove lock options after mint started", () => {
    it("not able to mint remove options after mint started", async () => {
      await qnft.startMint();

      await expect(qnftSettings.removeLockOption(0)).to.be.revertedWith(
        "QNFTSettings: mint already started"
      );

      await expect(qnftSettings.removeImageSet(0)).to.be.revertedWith(
        "QNFTSettings: mint already started"
      );

      await expect(qnftSettings.removeBgImage(0)).to.be.revertedWith(
        "QNFTSettings: mint already started"
      );

      await expect(
        qnftSettings.removeFavCoin(favCoins.A.name)
      ).to.be.revertedWith("QNFTSettings: mint already started");
    });
  });
});
