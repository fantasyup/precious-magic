// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract QNFT is Ownable, ERC721 {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // TODO: add events

    bool public mintStarted;
    bool public mintPaused; // valid on started = true;
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

    uint256 public constant EMOTION_COUNT_PER_NFT = 5;
    uint256 public constant BACKGROUND_IMAGE_COUNT = 4;
    uint256 public constant ARROW_IMAGE_COUNT = 3;
    struct NFTImage {
        string emotion1;
        string emotion2;
        string emotion3;
        string emotion4;
        string emotion5;
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
    struct NFTFavCoin {
        string name;
        string symbol;
        string icon;
        string website;
        string social;
        address erc20;
        string other;
    }
    NFTImage[] public nftImages; // -> constructor
    NFTBackgroundImage public bgImage; // -> constructor
    NFTArrowImage public arrowImage; // -> constructor
    NFTFavCoin[] public favCoins; // -> constructor
    mapping(string => uint256) private favCoinId; // -> constructor
    mapping(string => bool) public isFavCoin; // -> constructor

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

    function favCoinCount() public view returns (uint256) {
        return favCoins.length;
    }

    function favCoinFromName(string memory _name)
        public
        view
        returns (
            string memory name,
            string memory symbol,
            string memory icon,
            string memory website,
            string memory social,
            address erc20,
            string memory other
        )
    {
        require(isFavCoin[_name] == false, "QNFT: favcoin not exists");

        uint256 id = favCoinId[_name];
        require(favCoins.length >= id, "QNFT: favcoin not exists");

        NFTFavCoin memory favCoin = favCoins[id.sub(1)];

        return (
            favCoin.name,
            favCoin.symbol,
            favCoin.icon,
            favCoin.website,
            favCoin.social,
            favCoin.erc20,
            favCoin.other
        );
    }

    function setTotalSupply(uint256 _totalSupply) public onlyOwner {
        totalSupply = _totalSupply;
    }

    function setMintPriceMultiplier(uint256 _mintPriceMultiplier)
        public
        onlyOwner
    {
        mintPriceMultiplier = _mintPriceMultiplier;
    }

    function addMintOption(
        uint256 _ownableAmount,
        uint256 _lockDuration,
        uint256 _discount
    ) public onlyOwner {
        mintOptions.push(MintOption(_ownableAmount, _lockDuration, _discount));
    }

    function removeMintOption(uint256 _mintOptionId) public onlyOwner {
        require(mintStarted == false, "QNFT: mint already started");

        uint256 length = mintOptions.length;
        require(length > _mintOptionId, "QNFT: invalid mint option id");

        mintOptions[_mintOptionId] = mintOptions[length.sub(1)];
        mintOptions.pop();
    }

    function addImageSet(string[] memory _urls) public onlyOwner {
        require(
            _urls.length == EMOTION_COUNT_PER_NFT,
            "QNFT: image length does not match"
        );

        nftImages.push(
            NFTImage(_urls[0], _urls[1], _urls[2], _urls[3], _urls[4])
        );
    }

    function removeImageSet(uint256 _nftImageId) public onlyOwner {
        require(mintStarted == false, "QNFT: mint already started");

        uint256 length = nftImages.length;
        require(length > _nftImageId, "QNFT: invalid image set id");

        nftImages[_nftImageId] = nftImages[length.sub(1)];
        nftImages.pop();
    }

    function setBgImage(string[] memory _bgImage) public onlyOwner {
        // TODO: set bg image
        require(
            _bgImage.length == BACKGROUND_IMAGE_COUNT,
            "QNFT: image length does not match"
        );

        bgImage = NFTBackgroundImage(
            _bgImage[0],
            _bgImage[1],
            _bgImage[2],
            _bgImage[3]
        );
    }

    function addFavCoin(
        string memory _name,
        string memory _symbol,
        string memory _icon,
        string memory _website,
        string memory _social,
        address _erc20,
        string memory _other
    ) public onlyOwner {
        require(isFavCoin[_name] == false, "QNFT: favcoin already exists");

        favCoins.push(
            NFTFavCoin(_name, _symbol, _icon, _website, _social, _erc20, _other)
        );
        favCoinId[_name] = favCoins.length;
        isFavCoin[_name] = true;
    }

    function removeFavCoin(string memory _name) public onlyOwner {
        require(mintStarted == false, "QNFT: mint already started");

        require(isFavCoin[_name] == false, "QNFT: favcoin not exists");

        uint256 id = favCoinId[_name].sub(1);
        require(favCoins.length > id, "QNFT: favcoin not exists");

        uint256 last = favCoins.length.sub(1);
        favCoins[id] = favCoins[last];
        favCoinId[favCoins[id].name] = favCoinId[_name];
        favCoinId[_name] = 0;
        isFavCoin[_name] = false;

        favCoins.pop();
    }

    function startMint() public onlyOwner {
        mintStarted = true;
    }

    function pauseMint() public onlyOwner {
        require(mintPaused == false, "QNFT: mint already paused");
        mintPaused = true;
    }

    function unPauseMint() public onlyOwner {
        require(mintPaused == true, "QNFT: mint not paused");
        mintPaused = false;
    }

    function depositQstk(uint256 _amount) public onlyOwner {
        IERC20(qstk).safeTransferFrom(msg.sender, address(this), _amount);
    }

    function withdrawQstk(uint256 _amount) public onlyOwner {
        require(remainingQstk() >= _amount, "QNFT: not enough balance");
        IERC20(qstk).safeTransfer(msg.sender, _amount);
    }

    function mintNFT(
        uint256 _imageId,
        uint256 _favCoinId,
        uint256 _mintOption
    ) public payable {
        // TODO: mint NFT + assign to msg.sender + accept ETH from user + update lockedQstk and supply. should be locked < supply
        // calc mint price is calculated by params provided
        // NFT Mint Price = QSTK initial sale price (0.00001ETH) * QSTK quantity(user input) * discountRateByDuration +  ImageSetPrice (admin) + Coin selection price(admin)
    }

    function upgradeNftImage(uint256 _nftId, uint256 _imageId) public payable {
        // TODO: msg.value -> eth deposit value
        // update nftData
    }

    function upgradeNftCoin(uint256 _nftId, uint256 _favCoinId) public payable {
        // TODO: msg.value -> eth deposit value
        // update nftData
    }

    function upgradeNftMintOption(uint256 _nftId, uint256 _mintOptionId)
        public
        payable
    {
        // TODO: msg.value -> eth deposit value
        // update nftData
    }

    function unlockQstkFromNft(uint256 _nftId) public {
        // TODO: check nft ownership,  check locked time if expired. transfer qstk tokens to msg.sender.
    }
}
