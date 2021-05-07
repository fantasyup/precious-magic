const { ethers } = require("hardhat");

const units = (value) => ethers.utils.parseUnits(value.toString());
const days = (value) => value * 24 * 60 * 60;
const weeks = (value) => days(value * 7);
const months = (value) => days(value * 30);
const years = (value) => days(value * 365);

const nftImages = {
  A: {
    mintPrice: units(0.1),
    urls: ["A1", "A2", "A3", "A4", "A5"],
    designer_name: "A-name",
    designer_wallet: "0x0000000000000000000000000000000000000000",
    designer_meta: "A-meta",
  },
  B: {
    mintPrice: units(0.2),
    urls: ["B1", "B2", "B3", "B4", "B5"],
    designer_name: "B-name",
    designer_wallet: "0x0000000000000000000000000000000000000001",
    designer_meta: "B-meta",
  },
  C: {
    mintPrice: units(0.3),
    urls: ["C1", "C2", "C3", "C4", "C5"],
    designer_name: "C-name",
    designer_wallet: "0x0000000000000000000000000000000000000002",
    designer_meta: "C-meta",
  },
  D: {
    mintPrice: units(0.4),
    urls: ["D1", "D2", "D3", "D4", "D5"],
    designer_name: "D-name",
    designer_wallet: "0x0000000000000000000000000000000000000003",
    designer_meta: "D-meta",
  },
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

const lockOptions = {
  A: {
    minAmount: units(0),
    maxAmount: units(100),
    lockDuration: months(1),
    discount: 20,
  },
  B: {
    minAmount: units(100),
    maxAmount: units(200),
    lockDuration: months(2),
    discount: 30,
  },
  C: {
    minAmount: units(200),
    maxAmount: units(300),
    lockDuration: months(3),
    discount: 40,
  },
  D: {
    minAmount: units(0),
    maxAmount: units(400),
    lockDuration: months(6),
    discount: 50,
  },
};

module.exports = {
  lockOptions,
  favCoins,
  nftImages,
  bgImages,
  units,
  days,
  weeks,
  months,
  years,
};
