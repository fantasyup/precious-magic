import { deployments, upgrades } from "hardhat";
import {
  MockAtlasMine,
  MasterOfCoin,
  Magic,
  PrMagicToken,
  MagicDepositor,
  Legion,
  Treasure,
  RewardPool,
  LendingAuctionNft,
} from "../../typechain";
import {
  TEN_MILLION_MAGIC_BN,
  ONE_YEAR_IN_SECONDS,
  MAGIC_DEPOSITOR_SPLITS_DEFAULT_CONFIG,
  LEGION_TOKEN_IDS,
  ONE_TREAUSRE,
  TREASURE_TOKEN_IDS,
} from "../../utils/constants";
import { parseEther } from "ethers/lib/utils";

export const TreasureFixture = deployments.createFixture(async ({ ethers, getNamedAccounts }) => {
  const { deployer } = await getNamedAccounts();

  const [alice, bob, carol, dave, mallory] = await ethers.getSigners();
  const secondaryUsers = [bob, carol, dave];

  // deploy and initialize TreasureDAO contracts
  const Magic = await ethers.getContractFactory("Magic");
  const magicToken = <Magic>await Magic.deploy();

  const Treasure = await ethers.getContractFactory("Treasure");
  const treasure = <Treasure>await Treasure.deploy();

  const Legion = await ethers.getContractFactory("Legion");
  const legion = <Legion>await Legion.deploy();

  const MockAtlasMine = await ethers.getContractFactory("MockAtlasMine");
  const mockAtlasMine = <MockAtlasMine>await MockAtlasMine.deploy();

  const MasterOfCoin = await ethers.getContractFactory("MasterOfCoin");
  const masterOfCoin = <MasterOfCoin>await MasterOfCoin.deploy();

  await mockAtlasMine.init(magicToken.address, masterOfCoin.address);
  await masterOfCoin.init(magicToken.address);

  // override the utilization
  await mockAtlasMine.setUtilizationOverride(parseEther("1").div(2)); // 50%

  // fund magic
  await magicToken.connect(alice).mint(TEN_MILLION_MAGIC_BN);
  await magicToken.connect(bob).mint(TEN_MILLION_MAGIC_BN);
  await magicToken.connect(bob).transfer(masterOfCoin.address, TEN_MILLION_MAGIC_BN);
  for (const user of secondaryUsers) {
    await magicToken.connect(user).mint(TEN_MILLION_MAGIC_BN);
  }

  // mint nfts
  for (let i = 0; i < LEGION_TOKEN_IDS.length; i++) {
    await legion.mint(alice.address, LEGION_TOKEN_IDS[i]);
  }

  for (let i = 0; i < TREASURE_TOKEN_IDS.length; i++) {
    await treasure.mint(alice.address, TREASURE_TOKEN_IDS[i], ONE_TREAUSRE);
  }

  // set nft address to mockAtlasMine
  await mockAtlasMine.setLegion(legion.address);
  await mockAtlasMine.setTreasure(treasure.address);

  // add stream
  let { timestamp } = await ethers.provider.getBlock("latest");

  await masterOfCoin.addStream(
    mockAtlasMine.address,
    TEN_MILLION_MAGIC_BN,
    ++timestamp,
    timestamp + ONE_YEAR_IN_SECONDS * 2,
    false
  );

  // deploy Precious contracts
  const PrMagicToken = await ethers.getContractFactory("prMagicToken");
  const prMagicToken = <PrMagicToken>await PrMagicToken.deploy();

  const LendingAuctionNft = await ethers.getContractFactory("LendingAuctionNft");
  const lendingAuctionNft = <LendingAuctionNft>(
    await upgrades.deployProxy(LendingAuctionNft, [
      treasure.address,
      legion.address,
      mockAtlasMine.address,
    ])
  );
  await lendingAuctionNft.deployed();

  const MagicDepositor = await ethers.getContractFactory("MagicDepositor");
  const magicDepositor = <MagicDepositor>(
    await upgrades.deployProxy(MagicDepositor, [
      magicToken.address,
      prMagicToken.address,
      mockAtlasMine.address,
      treasure.address,
      legion.address,
      alice.address,
    ])
  );
  await magicDepositor.deployed();

  await (await lendingAuctionNft.setMagicDepositor(magicDepositor.address)).wait();

  const RewardPool = await ethers.getContractFactory("RewardPool");
  const rewardPool = <RewardPool>(
    await RewardPool.deploy(prMagicToken.address, magicToken.address, magicDepositor.address)
  );

  await magicDepositor.setConfig(
    MAGIC_DEPOSITOR_SPLITS_DEFAULT_CONFIG.rewards,
    deployer,
    rewardPool.address
  );
  await prMagicToken.transferOwnership(magicDepositor.address).then((tx) => tx.wait());

  const [stakeRewardSplit, treasuryAddress, stakingAddress] = await magicDepositor.getConfig();

  await magicToken.approve(magicDepositor.address, ethers.constants.MaxUint256);
  await magicToken.approve(rewardPool.address, ethers.constants.MaxUint256);
  await prMagicToken.approve(rewardPool.address, ethers.constants.MaxUint256);
  const atlasMine = mockAtlasMine;
  return {
    alice,
    bob,
    carol,
    dave,
    mallory,
    atlasMine,
    magicToken: magicToken as any,
    prMagicToken,
    magicDepositor,
    stakeRewardSplit,
    treasuryAddress,
    stakingAddress,
    rewardPool,
    treasure,
    legion,
    lendingAuctionNft,
  };
});
