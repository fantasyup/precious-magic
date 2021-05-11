// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../interface/structs.sol";
import "../interface/IQStk.sol";
import "../interface/IQNFT.sol";
import "../interface/IQNFTSettings.sol";

/**
 * @author fantasy
 */
contract QNFTSettings is Ownable, IQNFTSettings {
    using SafeMath for uint256;

    // events
    event SetNonTokenPriceMultiplier(
        address indexed owner,
        uint256 nonTokenPriceMultiplier
    );
    event AddLockOption(
        address indexed owner,
        uint256 minAmount,
        uint256 maxAmount,
        uint256 indexed lockDuration,
        uint256 discount // percent
    );
    event RemoveLockOption(address indexed owner, uint256 indexed lockOptionId);
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
    uint256 public qstkPrice; // qstk price
    uint256 public nonTokenPriceMultiplier; // percentage - should be multiplied to non token price - image + coin
    uint256 public tokenPriceMultiplier; // percentage - should be multiplied to token price - qstk

    LockOption[] public lockOptions; // array of lock options
    NFTBackgroundImage[] public bgImages; // array of background images
    NFTArrowImage public arrowImage; // arrow image to be used on frontend
    NFTImage[] public nftImages; // array of nft images
    NFTFavCoin[] public favCoins; // array of favorite coins
    mapping(string => uint256) internal favCoinIds; // mapping from coin name to coin id

    IQNFT public qnft; // QNFT contract address

    constructor() {
        qstkPrice = 0.00001 ether; // qstk price = 0.00001 ether
        nonTokenPriceMultiplier = PERCENT_MAX; // non token price multiplier = 100%;
        tokenPriceMultiplier = PERCENT_MAX; // token price multiplier = 100%;
    }

    /**
     * @dev returns the count of lock options
     */
    function lockOptionsCount() public view override returns (uint256) {
        return lockOptions.length;
    }

    /**
     * @dev returns the lock duration of given lock option id
     */
    function lockOptionLockDuration(uint256 _lockOptionId)
        public
        view
        override
        returns (uint256)
    {
        require(
            _lockOptionId < lockOptions.length,
            "QNFTSettings: invalid lock option"
        );

        return lockOptions[_lockOptionId].lockDuration;
    }

    /**
     * @dev adds a new lock option
     */
    function addLockOption(
        uint256 _minAmount,
        uint256 _maxAmount,
        uint256 _lockDuration,
        uint256 _discount
    ) public onlyOwner {
        require(_discount < PERCENT_MAX, "QNFTSettings: invalid discount");
        lockOptions.push(
            LockOption(_minAmount, _maxAmount, _lockDuration, _discount)
        );

        emit AddLockOption(
            msg.sender,
            _minAmount,
            _maxAmount,
            _lockDuration,
            _discount
        );
    }

    /**
     * @dev remove a lock option
     */
    function removeLockOption(uint256 _lockOptionId) public onlyOwner {
        require(
            qnft.mintStarted() == false,
            "QNFTSettings: mint already started"
        );

        uint256 length = lockOptions.length;
        require(length > _lockOptionId, "QNFTSettings: invalid lock option id");

        lockOptions[_lockOptionId] = lockOptions[length - 1];
        lockOptions.pop();

        emit RemoveLockOption(msg.sender, _lockOptionId);
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
     * @dev returns the mint price of given favorite coin
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
        uint256 _lockOptionId,
        uint256 _lockAmount,
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
            lockOptions.length > _lockOptionId,
            "QNFTSettings: invalid lock option"
        );

        LockOption memory lockOption = lockOptions[_lockOptionId];

        require(
            lockOption.minAmount <= _lockAmount + _freeAmount &&
                _lockAmount <= lockOption.maxAmount,
            "QNFTSettings: invalid mint amount"
        );
        require(favCoins.length > _favCoinId, "QNFTSettings: invalid fav coin");

        // mintPrice = qstkPrice * lockAmount * discountRate * tokenPriceMultiplier + (imageMintPrice + favCoinMintPrice) * nonTokenPriceMultiplier

        uint256 decimal = IQStk(qnft.qstk()).decimals();
        uint256 tokenPrice =
            qstkPrice
                .mul(_lockAmount)
                .mul(uint256(PERCENT_MAX).sub(lockOption.discount))
                .div(10**decimal)
                .div(PERCENT_MAX);
        tokenPrice = tokenPrice.mul(tokenPriceMultiplier).div(PERCENT_MAX);

        uint256 nonTokenPrice =
            nftImages[_imageId].mintPrice.add(favCoins[_favCoinId].mintPrice);
        nonTokenPrice = nonTokenPrice.mul(nonTokenPriceMultiplier).div(
            PERCENT_MAX
        );

        return tokenPrice.add(nonTokenPrice);
    }

    /**
     * @dev sets QNFT contract address
     */
    function setQNft(IQNFT _qnft) public onlyOwner {
        require(qnft != _qnft, "QNFTSettings: QNFT already set");

        qnft = _qnft;
    }

    /**
     * @dev sets token price multiplier - qstk
     */
    function setTokenPriceMultiplier(uint256 _tokenPriceMultiplier)
        public
        onlyOwner
    {
        tokenPriceMultiplier = _tokenPriceMultiplier;
    }

    /**
     * @dev sets non token price multiplier - image + coins
     */
    function setNonTokenPriceMultiplier(uint256 _nonTokenPriceMultiplier)
        public
        onlyOwner
    {
        nonTokenPriceMultiplier = _nonTokenPriceMultiplier;

        emit SetNonTokenPriceMultiplier(msg.sender, nonTokenPriceMultiplier);
    }
}
