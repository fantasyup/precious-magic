// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../interface/IQNFT.sol";

/**
 * @author fantasy
 */
contract QNFTSettings is Ownable {
    using SafeMath for uint256;

    // structs
    struct MintOption {
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
        // TODO: move this designer to NFT Image set
        string designer_name;
        address designer_address;
        string designer_meta_info;
    }
    struct NFTArrowImage {
        // global crypto market change - up, normal, down
        string image1;
        string image2;
        string image3;
    }
    struct NFTImage {
        uint256 mintPrice;
        string emotion1;
        string emotion2;
        string emotion3;
        string emotion4;
        string emotion5;
    }
    struct NFTFavCoin {
        uint256 mintPrice;
        string name;
        string symbol;
        string icon;
        string website;
        string social;
        address erc20;
        string other;
    }
    // events
    event SetMintPriceMultiplier(
        address indexed owner,
        uint256 mintPriceMultiplier
    );
    event AddMintOption(
        address indexed owner,
        uint256 minAmount,
        uint256 maxAmount,
        uint256 indexed lockDuration,
        uint256 discount // percent
    );
    event RemoveMintOption(address indexed owner, uint256 indexed mintOptionId);
    event AddImageSet(address indexed owner, uint256 mintPrice, string[] urls);
    event RemoveImageSet(address indexed owner, uint256 indexed nftImageId);
    event AddBgImage(address indexed owner, string[] urls);
    event RemoveBgImage(address indexed owner, uint256 indexed bgImageId);
    event AddFavCoin(
        address indexed owner,
        uint256 mintPrice,
        string indexed name,
        string symbol,
        string icon,
        string website,
        string social,
        address erc20,
        string other
    );
    event RemoveFavCoin(address indexed owner, string indexed name);

    // constants
    uint256 public constant EMOTION_COUNT_PER_NFT = 5;
    uint256 public constant BACKGROUND_IMAGE_COUNT = 4;
    uint256 public constant ARROW_IMAGE_COUNT = 3;
    uint256 public constant DEFAULT_IMAGE_PRICE = 0.006 ether;
    uint256 public constant DEFAULT_COIN_PRICE = 0.004 ether;
    uint256 public constant PERCENT_MAX = 100;

    // mint options set
    uint256 public initialSalePrice;
    uint256 public mintPriceMultiplier; // percent
    uint256 public mintDiscountRate; // percent

    MintOption[] public mintOptions;
    NFTBackgroundImage[] public bgImages;
    NFTArrowImage public arrowImage;
    NFTImage[] public nftImages;
    NFTFavCoin[] public favCoins;
    mapping(string => uint256) internal favCoinIds;

    address qnft;

    constructor() {
        // mint
        initialSalePrice = 0.00001 ether;
        mintPriceMultiplier = PERCENT_MAX; // 100%
    }

    // mint
    function setMintPriceMultiplier(uint256 _mintPriceMultiplier)
        public
        onlyOwner
    {
        mintPriceMultiplier = _mintPriceMultiplier;

        emit SetMintPriceMultiplier(msg.sender, mintPriceMultiplier);
    }

    function mintOptionsCount() public view returns (uint256) {
        return mintOptions.length;
    }

    function addMintOption(
        uint256 _minAmount,
        uint256 _maxAmount,
        uint256 _lockDuration,
        uint256 _discount
    ) public onlyOwner {
        require(_discount < PERCENT_MAX, "QNFTSettings: invalid discount");
        mintOptions.push(
            MintOption(_minAmount, _maxAmount, _lockDuration, _discount)
        );

        emit AddMintOption(
            msg.sender,
            _minAmount,
            _maxAmount,
            _lockDuration,
            _discount
        );
    }

    function removeMintOption(uint256 _mintOptionId) public onlyOwner {
        require(
            IQNFT(qnft).mintStarted() == false,
            "QNFTSettings: mint already started"
        );

        uint256 length = mintOptions.length;
        require(length > _mintOptionId, "QNFTSettings: invalid mint option id");

        mintOptions[_mintOptionId] = mintOptions[length - 1];
        mintOptions.pop();

        emit RemoveMintOption(msg.sender, _mintOptionId);
    }

    function nftImagesCount() public view returns (uint256) {
        return nftImages.length;
    }

    function addImageSet(uint256 _mintPrice, string[] memory _urls)
        public
        onlyOwner
    {
        require(
            _urls.length == EMOTION_COUNT_PER_NFT,
            "QNFTSettings: image length does not match"
        );

        nftImages.push(
            NFTImage(
                _mintPrice,
                _urls[0],
                _urls[1],
                _urls[2],
                _urls[3],
                _urls[4]
            )
        );

        emit AddImageSet(msg.sender, _mintPrice, _urls);
    }

    function removeImageSet(uint256 _nftImageId) public onlyOwner {
        require(
            IQNFT(qnft).mintStarted() == false,
            "QNFTSettings: mint already started"
        );

        uint256 length = nftImages.length;
        require(length > _nftImageId, "QNFTSettings: invalid id");

        nftImages[_nftImageId] = nftImages[length - 1];
        nftImages.pop();

        emit RemoveImageSet(msg.sender, _nftImageId);
    }

    function bgImagesCount() public view returns (uint256) {
        return bgImages.length;
    }

    function addBgImage(string[] memory _urls) public onlyOwner {
        require(
            _urls.length == BACKGROUND_IMAGE_COUNT,
            "QNFTSettings: background image length does not match"
        );

        bgImages.push(
            NFTBackgroundImage(_urls[0], _urls[1], _urls[2], _urls[3])
        );

        emit AddBgImage(msg.sender, _urls);
    }

    function removeBgImage(uint256 _bgImageId) public onlyOwner {
        require(
            IQNFT(qnft).mintStarted() == false,
            "QNFTSettings: mint already started"
        );

        uint256 length = bgImages.length;
        require(length > _bgImageId, "QNFTSettings: invalid id");

        bgImages[_bgImageId] = bgImages[length - 1];
        bgImages.pop();

        emit RemoveBgImage(msg.sender, _bgImageId);
    }

    function favCoinsCount() public view returns (uint256) {
        return favCoins.length;
    }

    function isFavCoin(string memory _name) public view returns (bool) {
        return favCoinIds[_name] != 0;
    }

    function favCoinFromName(string memory _name)
        public
        view
        returns (
            uint256 mintPrice,
            string memory name,
            string memory symbol,
            string memory icon,
            string memory website,
            string memory social,
            address erc20,
            string memory other
        )
    {
        uint256 id = favCoinIds[_name];
        require(id != 0, "QNFTSettings: favcoin not exists");

        NFTFavCoin memory favCoin = favCoins[id - 1];

        return (
            favCoin.mintPrice,
            favCoin.name,
            favCoin.symbol,
            favCoin.icon,
            favCoin.website,
            favCoin.social,
            favCoin.erc20,
            favCoin.other
        );
    }

    function addFavCoin(
        uint256 _mintPrice,
        string memory _name,
        string memory _symbol,
        string memory _icon,
        string memory _website,
        string memory _social,
        address _erc20,
        string memory _other
    ) public onlyOwner {
        require(favCoinIds[_name] == 0, "QNFTSettings: favcoin already exists");

        favCoins.push(
            NFTFavCoin(
                _mintPrice,
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

        emit AddFavCoin(
            msg.sender,
            _mintPrice,
            _name,
            _symbol,
            _icon,
            _website,
            _social,
            _erc20,
            _other
        );
    }

    function removeFavCoin(string memory _name) public onlyOwner {
        require(
            IQNFT(qnft).mintStarted() == false,
            "QNFTSettings: mint already started"
        );

        uint256 id = favCoinIds[_name];
        require(id != 0, "QNFTSettings: favcoin not exists");

        uint256 last = favCoins.length - 1;
        favCoins[id - 1] = favCoins[last];
        favCoinIds[favCoins[id - 1].name] = favCoinIds[_name];
        favCoinIds[_name] = 0;

        favCoins.pop();

        emit RemoveFavCoin(msg.sender, _name);
    }

    function calcMintPrice(
        uint256 _imageId,
        uint256 _bgImageId,
        uint256 _favCoinId,
        uint256 _mintOptionId,
        uint256 _mintAmount,
        uint256 _freeAmount
    ) external view returns (uint256) {
        require(
            nftImages.length > _imageId,
            "QNFTSettings: invalid image option"
        );
        require(
            bgImages.length > _bgImageId,
            "QNFTSettings: invalid background option"
        );
        require(
            mintOptions.length > _mintOptionId,
            "QNFTSettings: invalid mint option"
        );

        MintOption memory mintOption = mintOptions[_mintOptionId];

        require(
            mintOption.minAmount <= _mintAmount + _freeAmount &&
                _mintAmount <= mintOption.maxAmount,
            "QNFTSettings: invalid mint amount"
        );
        require(favCoins.length > _favCoinId, "QNFTSettings: invalid fav coin");

        // mintPrice = (initialSalePrice * mintAmount * discountRate + (imageMintPrice + favCoinMintPrice)) * mintMultiplier
        uint256 discountRate = getDiscountRate(mintOption.discount);
        uint256 qstkPrice =
            initialSalePrice.mul(_mintAmount).mul(discountRate).div(10**18).div(
                PERCENT_MAX
            );
        uint256 mintPrice =
            qstkPrice.add(nftImages[_imageId].mintPrice).add(
                favCoins[_favCoinId].mintPrice
            );

        return mintPrice.mul(mintPriceMultiplier).div(PERCENT_MAX);
    }

    function setQNft(address _qnft) public onlyOwner {
        require(qnft != _qnft, "QNFTSettings: QNFT already set");

        qnft = _qnft;
    }

    function setMintDiscountRate(uint256 _mintDiscountRate) public onlyOwner {
        require(
            _mintDiscountRate < PERCENT_MAX,
            "QNFTSettings: invalid discount rate"
        );
        mintDiscountRate = _mintDiscountRate;
    }

    // internal functions

    function getDiscountRate(uint256 _discount)
        internal
        view
        returns (uint256)
    {
        uint256 discount = _discount.add(mintDiscountRate);

        if (discount > PERCENT_MAX) {
            return 0;
        } else {
            return PERCENT_MAX.sub(discount);
        }
    }
}
