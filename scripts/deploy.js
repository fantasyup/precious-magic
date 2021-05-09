const { ethers } = require("hardhat");
const { units } = require("./utils");

const foundation = "0xed432d1dfbefff6127b24b421f93945467afe07c";

async function main() {
  const ethers = hre.ethers;

  console.log("network:", await ethers.provider.getNetwork());

  const signer = (await ethers.getSigners())[0];

  const QStkFactory = await ethers.getContractFactory("QStk");
  const qstk = await QStkFactory.deploy(units(300000000));
  await qstk.deployed();

  const QNFTSettingsFactory = await ethers.getContractFactory("QNFTSettings");
  const qnftSettings = await QNFTSettingsFactory.deploy();
  await qnftSettings.deployed();

  const QNFTGovFactory = await ethers.getContractFactory("QNFTGov");
  const qnftGov = await QNFTGovFactory.deploy();
  await qnftGov.deployed();

  const QNFTFactory = await ethers.getContractFactory("QNFT");
  const qnft = await QNFTFactory.deploy(
    qstk.address,
    qnftSettings.address,
    qnftGov.address,
    foundation
  );
  await qnft.deployed();

  console.log("Deployer: ", signer.address);
  console.log("Foundation: ", foundation);
  console.log("QStk: ", qstk.address);
  console.log("QNFTSettings: ", qnftSettings.address);
  console.log("QNFTGov: ", qnftGov.address);
  console.log("QNFT: ", qnft.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
