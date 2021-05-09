// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface IQNFT {
    // structs
    enum VoteStatus {
        NotStarted, // vote not started
        InProgress, // vote started, min vote duration not passed
        AbleToWithdraw, // vote started, min vote duration passed, safe vote end time not passed
        AbleToSafeWithdraw // vote started, min vote duration passed, safe vote end time passed
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
        bool unlocked;
        NFTMeta meta;
        NFTCreator creator;
    }

    // events
    event DepositQstk(address indexed owner, uint256 amount);
    event WithdrawQstk(address indexed owner, uint256 amount);
    event SetTotalSupply(address indexed owner, uint256 totalSupply);
    event StartMint(address indexed owner, uint256 startedAt);
    event PauseMint(address indexed owner, uint256 pausedAt);
    event UnpauseMint(address indexed owner, uint256 unPausedAt);
    event MintNFT(
        address indexed user,
        uint256 indexed nftId,
        uint256 imageId,
        uint256 bgImageId,
        uint256 favCoinId,
        uint256 lockOptionId,
        string creator_name,
        string color,
        string story
    );
    event UpgradeNftImage(
        address indexed user,
        uint256 indexed nftId,
        uint256 oldImageId,
        uint256 newImageId
    );
    event UpgradeNftBackground(
        address indexed user,
        uint256 indexed nftId,
        uint256 oldBgImageId,
        uint256 newBgImageId
    );
    event UpgradeNftCoin(
        address indexed user,
        uint256 indexed nftId,
        uint256 oldFavCoinId,
        uint256 newFavCoinId
    );
    event UnlockQstkFromNft(
        address indexed user,
        uint256 indexed nftId,
        uint256 amount
    );
    event SetFoundationWallet(address indexed owner, address wallet);

    function qstk() external view returns (address);

    function mintStarted() external view returns (bool);

    function mintFinished() external view returns (bool);

    function voteStatus() external view returns (VoteStatus);

    function qstkBalances(address user) external view returns (uint256);

    function totalAssignedQstk() external view returns (uint256);
}
