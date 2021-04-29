// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @author fantasy
 */
contract QBaseNFT is Ownable {
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
    event StartMint(address indexed owner, uint256 startedAt);
    event PauseMint(address indexed owner, uint256 pausedAt);
    event UnpauseMint(address indexed owner, uint256 unPausedAt);
    event SetFoundationWallet(address indexed owner, address wallet);

    // constants
    uint256 public constant EMOTION_COUNT_PER_NFT = 5;
    uint256 public constant BACKGROUND_IMAGE_COUNT = 4;
    uint256 public constant ARROW_IMAGE_COUNT = 3;
    uint256 public constant DEFAULT_IMAGE_PRICE = 0.006 ether;
    uint256 public constant DEFAULT_COIN_PRICE = 0.004 ether;
    uint256 public constant NFT_SALE_DURATION = 1209600; // 2 weeks

    uint256 public constant FOUNDATION_PERCENTAGE = 40; // 40%
    uint256 public constant MIN_VOTE_DURATION = 604800; // 1 week
    uint256 public constant SAFE_VOTE_END_DURATION = 1814400; // 3 weeks
    uint256 public constant VOTE_QUORUM = 50; // 50%

    // mint options set
    bool public mintStarted;
    uint256 public mintStartTime;
    bool public mintPaused;
    uint256 public initialSalePrice;
    uint256 public mintPriceMultiplier; // percent

    MintOption[] public mintOptions;
    NFTBackgroundImage[] public bgImages;
    NFTArrowImage public arrowImage;
    NFTImage[] public nftImages;
    NFTFavCoin[] public favCoins;
    mapping(string => bool) public isFavCoin;
    mapping(string => uint256) internal favCoinIds;

    // foundation
    address payable public foundationWallet;

    // vote options
    mapping(address => uint256) voteWeights;
    mapping(address => address) voteAddress;
    mapping(address => uint256) voteWeightsByAddress;

    constructor(address payable _foundationWallet) {
        // mint
        initialSalePrice = 0.00001 ether;
        mintPriceMultiplier = 100; // 100%

        // foundation
        foundationWallet = _foundationWallet;
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
        require(mintStarted == false, "QBaseNFT: mint already started");

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
        require(mintStarted == false, "QBaseNFT: mint already started");

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
        require(mintStarted == false, "QBaseNFT: mint already started");

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
        require(mintStarted == false, "QBaseNFT: mint already started");

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

    function startMint() public onlyOwner {
        mintStarted = true;
        mintStartTime = block.timestamp;

        emit StartMint(msg.sender, mintStartTime);
    }

    function pauseMint() public onlyOwner {
        require(mintStarted == true, "QBaseNFT: mint not started");
        require(mintPaused == false, "QBaseNFT: mint already paused");

        mintPaused = true;

        emit PauseMint(msg.sender, block.timestamp);
    }

    function unPauseMint() public onlyOwner {
        require(mintStarted == true, "QBaseNFT: mint not started");
        require(mintPaused == true, "QBaseNFT: mint not paused");

        mintPaused = false;

        emit UnpauseMint(msg.sender, block.timestamp);
    }

    // foundation
    function setFoundationWallet(address payable _foundationWallet)
        public
        onlyOwner
    {
        require(
            foundationWallet == _foundationWallet,
            "QBaseNFT: same foundation wallet"
        );

        foundationWallet = _foundationWallet;

        emit SetFoundationWallet(msg.sender, _foundationWallet);
    }
}
