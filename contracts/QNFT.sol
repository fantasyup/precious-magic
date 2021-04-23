// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "solidity-bytes-utils/contracts/BytesLib.sol";

contract QNFT is Ownable, ERC721 {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using BytesLib for bytes;

    // TODO: add events

    bool public mintStarted;
    bool public mintPaused; // valid on started = true;
    uint256 public totalSupply; // maximum mintable nft count
    uint256 public circulatingSupply; // current minted nft count

    address payable public treasury;

    address public qstk;
    uint256 public totalAssignedQstk; // total qstk balance assigned to nfts
    mapping(address => uint256) public qstkBalances;

    uint256 public initialSalePrice;
    uint256 public mintPriceMultiplier; // default = 1

    uint256 public constant EMOTION_COUNT_PER_NFT = 5;
    uint256 public constant BACKGROUND_IMAGE_COUNT = 4;
    uint256 public constant ARROW_IMAGE_COUNT = 3;
    uint256 public constant DEFAULT_IMAGE_PRICE = 0.006 ether;
    uint256 public constant DEFAULT_COIN_PRICE = 0.004 ether;

    struct MintOption {
        uint256 ownableAmount; // e.g. 0QSTK, 100QSTK, 200QSTK, 300QSTK
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
    struct NFTImage {
        uint256 price;
        string emotion1;
        string emotion2;
        string emotion3;
        string emotion4;
        string emotion5;
    }
    struct NFTFavCoin {
        uint256 price;
        string name;
        string symbol;
        string icon;
        string website;
        string social;
        address erc20;
        string other;
    }
    MintOption[] public mintOptions; // -> constructor
    NFTBackgroundImage public bgImage; // -> constructor
    NFTArrowImage public arrowImage; // -> constructor

    NFTImage[] public nftImages; // -> constructor
    NFTFavCoin[] public favCoins; // -> constructor
    mapping(string => bool) public isFavCoin; // -> constructor
    mapping(string => uint256) private favCoinIds; // -> constructor

    struct NFTMeta {
        string author;
        address creator;
        string color;
        string story;
        uint256 createdAt;
        bool unlocked;
    }
    struct NFTData {
        uint256 imageId;
        uint256 favCoinId;
        uint256 mintOptionId;
        NFTMeta meta;
    }
    NFTData[] public nftData;
    mapping(uint256 => bool) private isNftMinted;

    constructor(address _qstk, address payable _treasury)
        ERC721("Quiver NFT", "QNFT")
    {
        qstk = _qstk;
        treasury = _treasury;

        initialSalePrice = 0.00001 ether;
        mintPriceMultiplier = 1;
    }

    function totalQstkBalance() public view returns (uint256) {
        return IERC20(qstk).balanceOf(address(this));
    }

    function remainingQstk() public view returns (uint256) {
        return totalQstkBalance().sub(totalAssignedQstk);
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
            string memory other,
            uint256 price
        )
    {
        require(isFavCoin[_name] == false, "QNFT: favcoin not exists");

        uint256 id = favCoinIds[_name];
        require(favCoins.length >= id, "QNFT: favcoin not exists");

        NFTFavCoin memory favCoin = favCoins[id.sub(1)];

        return (
            favCoin.name,
            favCoin.symbol,
            favCoin.icon,
            favCoin.website,
            favCoin.social,
            favCoin.erc20,
            favCoin.other,
            favCoin.price
        );
    }

    function setTotalSupply(uint256 _totalSupply) public onlyOwner {
        require(
            _totalSupply <
                mintOptions.length.mul(nftImages.length).mul(favCoins.length),
            "QNFT: too big"
        );

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

    function addImageSet(uint256 price, string[] memory _urls)
        public
        onlyOwner
    {
        require(
            _urls.length == EMOTION_COUNT_PER_NFT,
            "QNFT: image length does not match"
        );

        nftImages.push(
            NFTImage(price, _urls[0], _urls[1], _urls[2], _urls[3], _urls[4])
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
        uint256 price,
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
            NFTFavCoin(
                price,
                _name,
                _symbol,
                _icon,
                _website,
                _social,
                _erc20,
                _other
            )
        );
        favCoinIds[_name] = favCoins.length;
        isFavCoin[_name] = true;
    }

    function removeFavCoin(string memory _name) public onlyOwner {
        require(mintStarted == false, "QNFT: mint already started");

        require(isFavCoin[_name] == false, "QNFT: favcoin not exists");

        uint256 id = favCoinIds[_name].sub(1);
        require(favCoins.length > id, "QNFT: favcoin not exists");

        uint256 last = favCoins.length.sub(1);
        favCoins[id] = favCoins[last];
        favCoinIds[favCoins[id].name] = favCoinIds[_name];
        favCoinIds[_name] = 0;
        isFavCoin[_name] = false;

        favCoins.pop();
    }

    function startMint() public onlyOwner {
        mintStarted = true;
    }

    function pauseMint() public onlyOwner {
        require(mintStarted == true, "QNFT: mint not started");
        require(mintPaused == false, "QNFT: mint already paused");

        mintPaused = true;
    }

    function unPauseMint() public onlyOwner {
        require(mintStarted == true, "QNFT: mint not started");
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
        uint256 _mintOptionId,
        string memory _author,
        string memory _color,
        string memory _story
    ) public payable {
        require(mintStarted == true, "QNFT: mint not started");
        require(
            circulatingSupply < totalSupply,
            "QNFT: nft count reached the total supply"
        );

        require(
            mintOptions.length > _mintOptionId,
            "QNFT: invalid mint option"
        );
        require(favCoins.length > _favCoinId, "QNFT: invalid fav coin");

        uint256 qstkAmount = mintOptions[_mintOptionId].ownableAmount;

        require(
            totalAssignedQstk.add(qstkAmount) <= totalSupply,
            "QNFT: insufficient qstk balance"
        );

        uint256 discount = mintOptions[_mintOptionId].discount;

        uint256 mintPrice =
            initialSalePrice
                .mul(qstkAmount)
                .mul(discount)
                .div(100)
                .add(nftImages[_imageId].price)
                .add(favCoins[_favCoinId].price);

        require(msg.value >= mintPrice, "QNFT: insufficient mint price");

        uint256 nftId = nftData.length;
        nftData.push(
            NFTData(
                _imageId,
                _favCoinId,
                _mintOptionId,
                NFTMeta(
                    _author,
                    msg.sender,
                    _color,
                    _story,
                    block.timestamp,
                    false
                )
            )
        );

        circulatingSupply = circulatingSupply.add(1);
        totalAssignedQstk = totalAssignedQstk.add(qstkAmount);
        qstkBalances[msg.sender] = qstkBalances[msg.sender].add(qstkAmount);

        _mint(address(this), nftId);
    }

    function upgradeNftImage(uint256 _nftId, uint256 _imageId) public payable {
        require(ownerOf(_nftId) == msg.sender, "QNFT: invalid owner");
        require(nftData.length >= _nftId, "QNFT: invalid nft id");
        require(nftImages.length >= _imageId, "QNFT: invalid image id");
        require(
            msg.value >= nftImages[_imageId].price,
            "QNFT: insufficient image upgrade price"
        );

        nftData[_nftId].imageId = _imageId;
    }

    function upgradeNftCoin(uint256 _nftId, uint256 _favCoinId) public payable {
        require(nftData.length >= _nftId, "QNFT: invalid nft id");
        require(ownerOf(_nftId) == msg.sender, "QNFT: invalid owner");
        require(favCoins.length >= _favCoinId, "QNFT: invalid image id");
        require(
            msg.value >= favCoins[_favCoinId].price,
            "QNFT: insufficient coin upgrade price"
        );

        nftData[_nftId].favCoinId = _favCoinId;
    }

    function unlockQstkFromNft(uint256 _nftId) public {
        // TODO: check nft ownership,  check locked time if expired. transfer qstk tokens to msg.sender.
        require(nftData.length >= _nftId, "QNFT: invalid nft id");
        require(ownerOf(_nftId) == msg.sender, "QNFT: invalid owner");

        NFTData storage item = nftData[_nftId];
        MintOption memory mintOption = mintOptions[item.mintOptionId];

        require(item.meta.unlocked == false, "QNFT: already unlocked");
        require(
            item.meta.createdAt.add(mintOption.lockDuration) >= block.timestamp,
            "QNFT: not able to unlock"
        );

        uint256 unlockAmount = mintOption.ownableAmount;
        IERC20(qstk).safeTransfer(msg.sender, unlockAmount);
        qstkBalances[msg.sender] = qstkBalances[msg.sender].sub(unlockAmount);
        totalAssignedQstk = totalAssignedQstk.sub(unlockAmount);

        item.meta.unlocked = true;
    }

    function setTreasury(address payable _treasury) public onlyOwner {
        require(treasury == _treasury, "QNFT: same treasury");

        treasury = _treasury;
    }

    function withdrawETH(uint256 _amount) public onlyOwner {
        require(_amount <= address(this).balance, "QNFT: Not enough eth.");

        treasury.transfer(_amount);
    }
}
