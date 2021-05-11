const hre = require("hardhat");
const { units } = require("./utils");

const foundation = "0xC241cE39C130963E2D0F7a6CCc0DDab3F84fe1de";

async function main() {
  const ethers = hre.ethers;

  console.log("network:", await ethers.provider.getNetwork());

  const signer = (await ethers.getSigners())[0];
  console.log("Deployer: ", signer.address);
  console.log("Foundation: ", foundation);

  const QStkFactory = await ethers.getContractFactory("QStk");
  const qstk = await QStkFactory.deploy(units(300000000));
  await qstk.deployed();
  console.log("QStk: ", qstk.address);

  const QNFTSettingsFactory = await ethers.getContractFactory("QNFTSettings");
  const qnftSettings = await QNFTSettingsFactory.deploy();
  await qnftSettings.deployed();
  console.log("QNFTSettings: ", qnftSettings.address);

  const QNFTGovFactory = await ethers.getContractFactory("QNFTGov");
  const qnftGov = await QNFTGovFactory.deploy();
  await qnftGov.deployed();
  console.log("QNFTGov: ", qnftGov.address);

  const QNFTFactory = await ethers.getContractFactory("QNFT");
  const qnft = await QNFTFactory.deploy(
    qstk.address,
    qnftSettings.address,
    qnftGov.address,
    foundation
  );
  await qnft.deployed();
  console.log("QNFT: ", qnft.address);

  await qnftGov.setQNft(qnft.address);
  await qnftSettings.setQNft(qnft.address);

  // verifying contracts
  await hre.run("verify:verify", {
    address: qstk.address,
    constructorArguments: [units(300000000)],
  });
  console.log("QSTK verified");

  await hre.run("verify:verify", {
    address: qnftSettings.address,
    constructorArguments: [],
  });
  console.log("QNFTSettings verified");

  await hre.run("verify:verify", {
    address: qnftGov.address,
    constructorArguments: [],
  });
  console.log("QNFTGov verified");

  await hre.run("verify:verify", {
    address: qnft.address,
    constructorArguments: [
      qstk.address,
      qnftSettings.address,
      qnftGov.address,
      foundation,
    ],
  });
  console.log("QNFT verified");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
