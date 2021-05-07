// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../interface/IQNFT.sol";
import "../interface/IQNFTSettings.sol";

/**
 * @author fantasy
 */
contract QNFTSettings is Ownable, IQNFTSettings {
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
    uint256 public constant PERCENT_MAX = 100;

    // mint options set
    uint256 public initialSalePrice; // qstk price at initial sale
    uint256 public mintPriceMultiplier; // percentage - should be multiplied to calculate mint price
    uint256 public mintDiscountRate; // percentage - overall discount rate of qstk price

    MintOption[] public mintOptions; // array of mint options
    NFTBackgroundImage[] public bgImages; // array of background images
    NFTArrowImage public arrowImage; // arrow image to be used on frontend
    NFTImage[] public nftImages; // array of nft images
    NFTFavCoin[] public favCoins; // array of favorite coins
    mapping(string => uint256) internal favCoinIds; // mapping from coin name to coin id

    IQNFT qnft; // QNFT contract address

    constructor() {
        initialSalePrice = 0.00001 ether; // qstk price = 0.00001 ether
        mintPriceMultiplier = PERCENT_MAX; // mint price multiplier = 100%;
    }

    /**
     * @dev sets the mint price multiplier
     */
    function setMintPriceMultiplier(uint256 _mintPriceMultiplier)
        public
        onlyOwner
    {
        mintPriceMultiplier = _mintPriceMultiplier;

        emit SetMintPriceMultiplier(msg.sender, mintPriceMultiplier);
    }

    /**
     * @dev returns the count of mint options
     */
    function mintOptionsCount() public view override returns (uint256) {
        return mintOptions.length;
    }

    /**
     * @dev returns the lock duration of given mint option id
     */
    function mintOptionLockDuration(uint256 _mintOptionId)
        public
        view
        override
        returns (uint256)
    {
        require(
            _mintOptionId < mintOptions.length,
            "QNFTSettings: invalid mint option"
        );

        return mintOptions[_mintOptionId].lockDuration;
    }

    /**
     * @dev adds a new mint option
     */
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

    /**
     * @dev remove a mint option
     */
    function removeMintOption(uint256 _mintOptionId) public onlyOwner {
        require(
            qnft.mintStarted() == false,
            "QNFTSettings: mint already started"
        );

        uint256 length = mintOptions.length;
        require(length > _mintOptionId, "QNFTSettings: invalid mint option id");

        mintOptions[_mintOptionId] = mintOptions[length - 1];
        mintOptions.pop();

        emit RemoveMintOption(msg.sender, _mintOptionId);
    }

    /**
     * @dev returns the count of nft images sets
     */
    function nftImagesCount() public view override returns (uint256) {
        return nftImages.length;
    }

    /**
     * @dev returns the mint price of given nft image id
     */
    function nftImageMintPrice(uint256 _nftImageId)
        public
        view
        override
        returns (uint256)
    {
        require(
            _nftImageId < nftImages.length,
            "QNFTSettings: invalid image id"
        );
        return nftImages[_nftImageId].mintPrice;
    }

    /**
     * @dev adds a new nft iamges set
     */
    function addImageSet(
        uint256 _mintPrice,
        string[] memory _urls,
        string memory _designer_name,
        address _designer_wallet,
        string memory _designer_meta
    ) public onlyOwner {
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
                _urls[4],
                NFTImageDesigner(
                    _designer_name,
                    _designer_wallet,
                    _designer_meta
                )
            )
        );

        emit AddImageSet(msg.sender, _mintPrice, _urls);
    }

    /**
     * @dev removes a nft images set
     */
    function removeImageSet(uint256 _nftImageId) public onlyOwner {
        require(
            qnft.mintStarted() == false,
            "QNFTSettings: mint already started"
        );

        uint256 length = nftImages.length;
        require(length > _nftImageId, "QNFTSettings: invalid id");

        nftImages[_nftImageId] = nftImages[length - 1];
        nftImages.pop();

        emit RemoveImageSet(msg.sender, _nftImageId);
    }

    /**
     * @dev returns the count of background images
     */
    function bgImagesCount() public view override returns (uint256) {
        return bgImages.length;
    }

    /**
     * @dev adds a new background image
     */
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

    /**
     * @dev removes a background image
     */
    function removeBgImage(uint256 _bgImageId) public onlyOwner {
        require(
            qnft.mintStarted() == false,
            "QNFTSettings: mint already started"
        );

        uint256 length = bgImages.length;
        require(length > _bgImageId, "QNFTSettings: invalid id");

        bgImages[_bgImageId] = bgImages[length - 1];
        bgImages.pop();

        emit RemoveBgImage(msg.sender, _bgImageId);
    }

    /**
     * @dev returns the count of favorite coins
     */
    function favCoinsCount() public view override returns (uint256) {
        return favCoins.length;
    }

    /**
     * @dev returns the mint price of given favorite coin id
     */
    function favCoinMintPrice(uint256 _favCoinId)
        public
        view
        override
        returns (uint256)
    {
        require(
            _favCoinId < favCoins.length,
            "QNFTSettings: invalid favcoin id"
        );

        return favCoins[_favCoinId].mintPrice;
    }

    /**
     * @dev checks if given is a favorite coin
     */
    function isFavCoin(string memory _name) public view returns (bool) {
        return favCoinIds[_name] != 0;
    }

    /**
     * @dev returns fav coin informations of given name
     */
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

    /**
     * @dev adds a new favorite coin
     */
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

    /**
     * @dev removes a favorite coin
     */
    function removeFavCoin(string memory _name) public onlyOwner {
        require(
            qnft.mintStarted() == false,
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

    /**
     * @dev calculate mint price of given mint options
     */
    function calcMintPrice(
        uint256 _imageId,
        uint256 _bgImageId,
        uint256 _favCoinId,
        uint256 _mintOptionId,
        uint256 _mintAmount,
        uint256 _freeAmount
    ) public view override returns (uint256) {
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

    /**
     * @dev sets QNFT contract address
     */
    function setQNft(IQNFT _qnft) public onlyOwner {
        require(qnft != _qnft, "QNFTSettings: QNFT already set");

        qnft = _qnft;
    }

    /**
     * @dev sets overall discount rate of qstk price
     */
    function setMintDiscountRate(uint256 _mintDiscountRate) public onlyOwner {
        require(
            _mintDiscountRate < PERCENT_MAX,
            "QNFTSettings: invalid discount rate"
        );
        mintDiscountRate = _mintDiscountRate;
    }

    // internal functions

    /**
     * @dev calculate discount rate based on given mint option and overall discount rate
     */
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
