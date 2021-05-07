const chai = require("chai");
const { solidity } = require("ethereum-waffle");
const { ethers } = require("hardhat");

const { expect } = chai;

chai.use(solidity);

const units = (value) => ethers.utils.parseUnits(value.toString());

describe("QNFT", () => {
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

  describe("QNFT: correct free allocation management", () => {
    it("Only owner can set free allocation supply", () => {});
    it("Only owner can set user's free allocation", () => {});
    it("Free allocation total supply should be increased and decreased correctly", () => {});
    it("Free allocation total supply should NOT exceed free allocation max supply", () => {});
    it("Free allocation max supply should NOT be able set less than current supply", () => {});
    it("Free allocation remaining supply should not exceed remaining QSTK balance", () => {
      // remaining_supply = max_free_allocation - free_distribution
    });
    it("Free allocation remaining supply should not be mintable via payment by others", () => {
      // Is this required?
    });
  });

  describe("QNFT: NFT supply management", () => {
    it("circulating supply should be managed correctly by mint", () => {});
    it("circulating supply should not exceed total supply", () => {});
    it("total supply should be bigger than circulating supply", () => {
      // TODO: should not able to set total supply bigger than circulating supply
    });
  });

  describe("QNFT: mint start, pause / unpause management", () => {
    it("mint should be only available when mint start", () => {});
    it("mint should not be possible when it is paused", () => {});
    it("mint should be possible after unpause", () => {});
  });

  describe("QNFT: mint should handle things correctly", () => {
    describe("free allocation", () => {
      it("When mint, free allocation + mint amount should NOT exceed remaining QSTK balance", () => {});
      it("When mint, free allocation for the user should be zero", () => {});
      it("When mint, free allocation distribution amount should be increased", () => {});
    });
    describe("mint management", () => {
      it("user should pay enough for minting", () => {});
      it("user should get correct qstk amount after mint", () => {});
      it("provided image, favCoin, mintOption should be unique", () => {
        // TODO: isNftMinted(_imageId, _bgImageId, _favCoinId, _mintOptionId) is wrong, should omit out bgImageId
      });
      it("should modify total assigned qstk correctly", () => {});
      it("qstk balance of a user correctly", () => {});
      it("foundation should get correct percentage of payment per purchase", () => {});
      it("check mint after mint period finish", () => {
        // TODO: should fail
      });
    });
  });
  describe("QNFT: nft upgrade management", () => {
    it("should be able to upgrade nft image set", () => {
      // TODO: check original flags are removed
      // TODO: check new flags are created correctly
      // TODO: check payment is correct
      // TODO: check ownership of nft
      // TODO: check upgrade params are valid
      // TODO: check upgrade payment is paid to foundation
      // TODO: should update the info correcctly
    });
    it("should be able to upgrade nft background set", () => {
      // TODO: check params are valid
      // TODO: check ownership of nft
      // TODO: background update should be free: current implementation is incorrect, should not be payable
      // TODO: should update the info correcctly
    });
    it("should be able to upgrade nft fav coin", () => {
      // TODO: check params are valid
      // TODO: check ownership of nft
      // TODO: check upgrade payment is paid to foundation
      // TODO: should update the info correctly
    });
  });
  describe("QNFT: foundation wallet management", () => {});
  describe("QNFT: withdraw of Qstk after time pass", () => {
    it("check double withdraw", () => {});
    it("check withdraw before time", () => {});
    it("check withdraw after time", () => {});
    it("check global variables update after withdraw", () => {});
  });
  describe("QNFT: Qstk token upgrade", () => {
    // TODO: when doing upgrade, Qstk token should be sent same amount as before.
  });
  describe("QNFT: governance process for Quiver IDAO multisig address withdraw", () => {
    describe("QNFT: correct withdraw amount of ETH into multisig address", () => {});
    describe("QNFT: vote quorum check before withdraw", () => {});
    describe("QNFT: vote change check", () => {});
    describe("QNFT: vote correctly change global variables and individual variables", () => {});
    describe("QNFT: safe withdraw when quorum does not reach and it's not withdrawn already", () => {});
  });
});
