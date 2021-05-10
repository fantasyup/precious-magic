// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

// structs
enum VoteStatus {
    NotStarted, // vote not started
    InProgress, // vote started, min vote duration not passed
    AbleToWithdraw, // vote started, min vote duration passed, safe vote end time not passed
    AbleToSafeWithdraw // vote started, min vote duration passed, safe vote end time passed
}

struct LockOption {
    uint256 minAmount; // e.g. 0QSTK, 100QSTK, 200QSTK, 300QSTK
    uint256 maxAmount; // e.g. 0QSTK, 100QSTK, 200QSTK, 300QSTK
    uint256 lockDuration; // e.g. 3 months, 6 months, 1 year
    uint256 discount; // percent e.g. 10%, 20%, 30%
}
struct NFTBackgroundImage {
    // Sunrise-Noon-Evening-Night: based on local time
    string background1;
    string background2;
    string background3;
    string background4;
}
struct NFTArrowImage {
    // global crypto market change - up, normal, down
    string image1;
    string image2;
    string image3;
}
struct NFTImageDesigner {
    // information of NFT iamge designer
    string name;
    address wallet;
    string meta_info;
}
struct NFTImage {
    // each NFT has 5 emotions
    uint256 mintPrice;
    string emotion1;
    string emotion2;
    string emotion3;
    string emotion4;
    string emotion5;
    NFTImageDesigner designer;
}
struct NFTFavCoin {
    // information of favorite coins
    uint256 mintPrice;
    string name;
    string symbol;
    string icon;
    string website;
    string social;
    address erc20;
    string other;
}
struct NFTCreator {
    // NFT minter informations
    string name;
    address wallet;
}
struct NFTMeta {
    // NFT meta informations
    string name;
    string color;
    string story;
}
struct NFTData {
    // NFT data
    uint256 imageId;
    uint256 bgImageId;
    uint256 favCoinId;
    uint256 lockOptionId;
    uint256 lockAmount;
    uint256 defaultImageIndex;
    uint256 createdAt;
    bool withdrawn;
    NFTMeta meta;
    NFTCreator creator;
}
