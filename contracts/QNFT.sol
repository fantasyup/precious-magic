// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract QNFT is Ownable, ERC721 {
    // TODO: safemath, safeERC20

    // TODO: add events

    bool public started;
    bool public paused; // valid on started = true;
    address public qstk;
    uint256 public totalSupply; // maximum mintable nft count
    uint256 public circulatingSupply; // current minted nft count
    uint256 public totalAssignedQstk; // total qstk balance assigned to nfts
    uint256 public mintPriceMultiplier = 1; // default = 1

    mapping(uint256 => uint256) public qstkBalances;
    // TODO: timestamp
    mapping(uint256 => uint256) public unlockTime;

    struct MintOption {
        uint256 ownableAmount; // e.g. 0QSTK, 100QSTK, 200QSTK, 300QSTK
        uint256 lockDuration; // e.g. 3 months, 6 months, 1 year
        uint256 discount; // percent e.g. 10%, 20%, 30%
    }
    MintOption[] public mintOptions; // -> constructor

    struct NFTImage {
        string emotion1;
        string emotion2;
        string emotion3;
        string emotion4;
        string emotion5;
    }
    struct NFTBackgroundImage {
        string background1;
        string background2;
        string background3;
    }
    struct NFTFavCoin {
        string name;
        string icon;
        string website;
        string social;
        address erc20;
        string other;
    }
    NFTImage[] public nftImages; // -> constructor
    NFTBackgroundImage public bgImage; // -> constructor
    NFTFavCoin[] public favCoins; // -> constructor
    mapping(string => bool) isFavCoin; // -> constructor

    struct NFTMeta {
        string author;
        address creator;
        string color;
        string story;
    }
    struct NFTData {
        uint256 imageId;
        uint256 favCoinId;
        uint256 mintOptionId;
        NFTMeta meta;
    }
    mapping(uint256 => NFTData) public nftData;

    constructor(address _qstk) ERC721("Quiver NFT", "QNFT") {
        qstk = _qstk;
    }

    function totalQstkBalance() public view returns (uint256) {
        return IERC20(qstk).balanceOf(address(this));
    }

    function remainingQstk() public view returns (uint256) {
        return totalQstkBalance() - totalAssignedQstk;
    }

    function setTotalSupply(uint256 _totalSupply) public {
        totalSupply = _totalSupply;
    }

    function setMintPriceMultiplier(uint256 _mintPriceMultiplier)
        public
        onlyOwner
    {
        // set mintpricemultiplier
    }

    function addMintOption() public onlyOwner {}

    function removeMintOption() public onlyOwner {
        // TODO: should check if mint already started
    }

    function addImageSet(string[] memory _urls) public onlyOwner {
        // TODO: add emotions to nftImages
    }

    function removeImageSet(uint256 _nftImageId) public onlyOwner {
        // TODO; remove from nftImages
        // TODO: should check if mint already started
    }

    function setBgImage(string[] memory _bgImage) public onlyOwner {
        // TODO: set bg image
    }

    function addFavCoin(string memory _favCoin) public onlyOwner {
        // TODO: add favCoins + isFavCoin
    }

    function removeFavCoin(string memory _favCoin) public onlyOwner {
        // TODO: remove favCoins + isFavCoin
        // TODO: should check if mint already started
    }

    function startMint() public onlyOwner {
        // pause NFT mint from now
    }

    function pauseMint() public onlyOwner {
        // pause NFT mint from now
    }

    function unPauseMint() public onlyOwner {
        // unpause NFT mint from now
    }

    function depositQstk(uint256 _amount) public onlyOwner {
        // TODO: transfer qstk's amount to contract from msg.sender
    }

    function withdrawQstk(uint256 _amount) public onlyOwner {
        // TODO: transfer to msg.sender from contract
        // locked amount shouldn't be transferred
    }

    function mintNFT(
        uint256 imageId,
        uint256 favCoinId,
        uint256 mintOption
    ) public payable {
        // TODO: mint NFT + assign to msg.sender + accept ETH from user + update lockedQstk and supply. should be locked < supply
        // calc mint price is calculated by params provided
        // NFT Mint Price = QSTK initial sale price (0.00001ETH) * QSTK quantity(user input) * discountRateByDuration +  ImageSetPrice (admin) + Coin selection price(admin)
    }

    function upgradeNftImage(uint256 nftId, uint256 imageId) public payable {
        // TODO: msg.value -> eth deposit value
        // update nftData
    }

    function upgradeNftCoin(uint256 nftId, uint256 favCoinId) public payable {
        // TODO: msg.value -> eth deposit value
        // update nftData
    }

    function upgradeNftMintOption(uint256 nftId, uint256 mintOptionId)
        public
        payable
    {
        // TODO: msg.value -> eth deposit value
        // update nftData
    }

    function unlockQstkFromNft(uint256 nftId) public {
        // TODO: check nft ownership,  check locked time if expired. transfer qstk tokens to msg.sender.
    }
}
