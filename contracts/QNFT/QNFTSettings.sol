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
        uint256 ownableAmount,
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

    // mint options set
    uint256 public initialSalePrice;
    uint256 public mintPriceMultiplier; // percent

    MintOption[] public mintOptions;
    NFTBackgroundImage[] public bgImages;
    NFTArrowImage public arrowImage;
    NFTImage[] public nftImages;
    NFTFavCoin[] public favCoins;
    mapping(string => bool) public isFavCoin;
    mapping(string => uint256) internal favCoinIds;

    address qnft;

    constructor() {
        // mint
        initialSalePrice = 0.00001 ether;
        mintPriceMultiplier = 100; // 100%
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
        uint256 _ownableAmount,
        uint256 _lockDuration,
        uint256 _discount
    ) public onlyOwner {
        mintOptions.push(MintOption(_ownableAmount, _lockDuration, _discount));

        emit AddMintOption(
            msg.sender,
            _ownableAmount,
            _lockDuration,
            _discount
        );
    }

    function removeMintOption(uint256 _mintOptionId) public onlyOwner {
        require(
            IQNFT(qnft).mintStarted() == false,
            "QBaseNFT: mint already started"
        );

        uint256 length = mintOptions.length;
        require(length > _mintOptionId, "QBaseNFT: invalid mint option id");

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
            "QBaseNFT: image length does not match"
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
            "QBaseNFT: mint already started"
        );

        uint256 length = nftImages.length;
        require(length > _nftImageId, "QBaseNFT: invalid id");

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
            "QBaseNFT: background image length does not match"
        );

        bgImages.push(
            NFTBackgroundImage(_urls[0], _urls[1], _urls[2], _urls[3])
        );

        emit AddBgImage(msg.sender, _urls);
    }

    function removeBgImage(uint256 _bgImageId) public onlyOwner {
        require(
            IQNFT(qnft).mintStarted() == false,
            "QBaseNFT: mint already started"
        );

        uint256 length = bgImages.length;
        require(length > _bgImageId, "QBaseNFT: invalid id");

        bgImages[_bgImageId] = bgImages[length - 1];
        bgImages.pop();

        emit RemoveBgImage(msg.sender, _bgImageId);
    }

    function favCoinsCount() public view returns (uint256) {
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
            uint256 mintPrice
        )
    {
        require(isFavCoin[_name] == false, "QBaseNFT: favcoin not exists");

        uint256 id = favCoinIds[_name];
        require(favCoins.length >= id, "QBaseNFT: favcoin not exists");

        NFTFavCoin memory favCoin = favCoins[id - 1];

        return (
            favCoin.name,
            favCoin.symbol,
            favCoin.icon,
            favCoin.website,
            favCoin.social,
            favCoin.erc20,
            favCoin.other,
            favCoin.mintPrice
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
        require(isFavCoin[_name] == false, "QBaseNFT: favcoin already exists");

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
        isFavCoin[_name] = true;

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
            "QBaseNFT: mint already started"
        );

        require(isFavCoin[_name] == false, "QBaseNFT: favcoin not exists");

        uint256 id = favCoinIds[_name] - 1;
        require(favCoins.length > id, "QBaseNFT: favcoin not exists");

        uint256 last = favCoins.length - 1;
        favCoins[id] = favCoins[last];
        favCoinIds[favCoins[id].name] = favCoinIds[_name];
        favCoinIds[_name] = 0;
        isFavCoin[_name] = false;

        favCoins.pop();

        emit RemoveFavCoin(msg.sender, _name);
    }

    function calcMintPrice(
        uint256 _imageId,
        uint256 _bgImageId,
        uint256 _favCoinId,
        uint256 _mintOptionId
    ) external view returns (uint256) {
        require(nftImages.length > _imageId, "QNFT: invalid image option");
        require(
            bgImages.length > _bgImageId,
            "QNFT: invalid background option"
        );
        require(
            mintOptions.length > _mintOptionId,
            "QNFT: invalid mint option"
        );
        require(favCoins.length > _favCoinId, "QNFT: invalid fav coin");

        return
            (
                initialSalePrice
                    .mul(mintOptions[_mintOptionId].ownableAmount)
                    .mul(mintOptions[_mintOptionId].discount)
                    .div(100)
                    .add(nftImages[_imageId].mintPrice)
            )
                .mul(mintPriceMultiplier)
                .div(100);
    }

    function setQNft(address _qnft) public onlyOwner {
        require(qnft != _qnft, "QNFTSettings: QNFT already set");

        qnft = _qnft;
    }
}
