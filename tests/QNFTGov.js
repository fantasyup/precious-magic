const chai = require("chai");
const { time } = require("@openzeppelin/test-helpers");
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

describe("QNFT", () => {
  let qstk, qnft, qnftSettings, qnftGov;
  let deployer, foundation, multisig, user1, user2, user3;

  const timeTravel = async (seconds) => {
    await time.increase(seconds);
  };
  const mintNFT = async (
    user,
    imageId,
    bgImageId,
    favCoinId,
    lockOptionId,
    lockAmount,
    defaultImageIndex,
    name,
    creator_name,
    color,
    story,
    freeAmount
  ) => {
    await qnft
      .connect(user)
      .mintNFT(
        imageId,
        bgImageId,
        favCoinId,
        lockOptionId,
        lockAmount,
        defaultImageIndex,
        name,
        creator_name,
        color,
        story,
        {
          value: await qnftSettings.calcMintPrice(
            imageId,
            bgImageId,
            favCoinId,
            lockOptionId,
            lockAmount,
            freeAmount
          ),
        }
      );
  };

  before(async () => {
    const accounts = await ethers.getSigners();
    deployer = accounts[0];
    foundation = accounts[1];
    multisig = accounts[2];
    user1 = accounts[3];
    user2 = accounts[4];
    user3 = accounts[5];

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

    await qnftSettings.setQNft(qnft.address);
  });

  it("QNFTGov: Should be able to set QNFT", async () => {
    await expect(
      qnftGov.connect(user1).setQNft(qnft.address)
    ).to.be.revertedWith("Ownable: caller is not the owner");

    await qnftGov.setQNft(qnft.address);

    await expect(qnftGov.setQNft(qnft.address)).to.be.revertedWith(
      "QNFTGov: QNFT already set"
    );
  });

  it("QNFTGov: Prepare QNFTGov tests", async () => {
    await qstk.approve(qnft.address, units(10000000));
    await qnft.depositQstk(units(10000000));

    await qnftSettings.addLockOption(...Object.values(lockOptions.A));
    await qnftSettings.addLockOption(...Object.values(lockOptions.B));
    await qnftSettings.addLockOption(...Object.values(lockOptions.C));
    await qnftSettings.addLockOption(...Object.values(lockOptions.D));
    await qnftSettings.addImageSet(...Object.values(nftImages.A));
    await qnftSettings.addImageSet(...Object.values(nftImages.B));
    await qnftSettings.addImageSet(...Object.values(nftImages.C));
    await qnftSettings.addImageSet(...Object.values(nftImages.D));
    await qnftSettings.addBgImage(bgImages.A);
    await qnftSettings.addBgImage(bgImages.B);
    await qnftSettings.addBgImage(bgImages.C);
    await qnftSettings.addBgImage(bgImages.D);
    await qnftSettings.addFavCoin(...Object.values(favCoins.A));
    await qnftSettings.addFavCoin(...Object.values(favCoins.B));
    await qnftSettings.addFavCoin(...Object.values(favCoins.C));
    await qnftSettings.addFavCoin(...Object.values(favCoins.D));

    await qnftSettings.setTokenPriceMultiplier(200);
    await qnftSettings.setNonTokenPriceMultiplier(200);
  });

  it("QNFTGov: Should vote on multisig", async () => {
    await expect(
      qnftGov.voteGovernanceAddress(multisig.address)
    ).to.be.revertedWith("QNFTGov: mint not started");

    await qnft.startMint();
    await qnft.setTotalSupply(3);
    await mintNFT(
      user1,
      0,
      0,
      0,
      0,
      units(50),
      0,
      "user1-nft",
      "user1",
      "red",
      "This is user1's red nft",
      0
    );
    await mintNFT(
      user2,
      0,
      0,
      0,
      1,
      units(150),
      0,
      "user2-nft",
      "user2",
      "blue",
      "This is user2's blue nft",
      0
    );
    await mintNFT(
      user3,
      0,
      0,
      0,
      2,
      units(250),
      0,
      "user3-nft",
      "user3",
      "green",
      "This is user3's green nft",
      0
    );

    await expect(
      qnftGov.voteGovernanceAddress(multisig.address)
    ).to.be.revertedWith("QNFTGov: NFT sale not ended");

    await timeTravel(weeks(2));

    await expect(
      qnftGov.voteGovernanceAddress(multisig.address)
    ).to.be.revertedWith("QNFTGov: non-zero qstk balance");

    await qnftGov.connect(user1).voteGovernanceAddress(multisig.address);
  });

  it("QNFTGov: Shoule withdraw to governance", async () => {
    await expect(
      qnftGov.connect(user1).safeWithdraw(multisig.address)
    ).to.be.revertedWith("Ownable: caller is not the owner");

    await expect(
      qnftGov.withdrawToGovernanceAddress(multisig.address)
    ).to.be.revertedWith("QNFTGov: vote in progress");

    await expect(qnftGov.safeWithdraw(multisig.address)).to.be.revertedWith(
      "QNFTGov: vote in progress"
    );

    await timeTravel(weeks(1));

    await expect(
      qnftGov.withdrawToGovernanceAddress(multisig.address)
    ).to.be.revertedWith(
      "QNFTGov: specified multisig address is not voted enough"
    );

    await expect(qnftGov.safeWithdraw(multisig.address)).to.be.revertedWith(
      "QNFTGov: wait until safe vote end time"
    );

    await timeTravel(weeks(2));

    await qnftGov.safeWithdraw(multisig.address);

    await qnftGov.connect(user3).voteGovernanceAddress(multisig.address);
    await qnftGov.withdrawToGovernanceAddress(multisig.address);
  });
});
