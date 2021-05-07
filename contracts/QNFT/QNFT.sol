// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "solidity-bytes-utils/contracts/BytesLib.sol";

import "../interface/IQNFTGov.sol";
import "../interface/IQNFTSettings.sol";

/**
 * @author fantasy
 */
contract QNFT is Ownable, ERC721, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using BytesLib for bytes;

    // structs
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
        uint256 mintOptionId;
        uint256 mintAmount;
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
        uint256 mintOptionId,
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

    // constants
    uint256 public constant NFT_SALE_DURATION = 1209600; // 2 weeks
    uint256 public constant FOUNDATION_PERCENTAGE = 30; // 30%
    uint256 public constant MIN_VOTE_DURATION = 604800; // 1 week
    uint256 public constant SAFE_VOTE_END_DURATION = 1814400; // 3 weeks

    // qstk
    address public qstk;
    uint256 public totalAssignedQstk; // total qstk balance assigned to nfts
    mapping(address => uint256) public qstkBalances; // locked qstk balances per user
    mapping(address => uint256) public freeAllocations; // free allocated qstk balances per user
    uint256 totalFreeAllocations; // total free allocated qstk balances
    uint256 distributedFreeAllocations; // total distributed amount of free allocations

    // nft
    IQNFTSettings settings; // QNFTSettings contract address
    IQNFTGov governance; // QNFTGov contract address
    uint256 public totalSupply; // maximum mintable nft count
    mapping(uint256 => NFTData) public nftData;
    mapping(uint256 => uint256) private nftIds;
    uint256 private nftCount; // circulating supply - minted nft counts

    // mint options set
    bool public mintStarted;
    bool public mintPaused;
    uint256 public mintStartTime;

    // foundation
    address payable public foundationWallet; // periodically sends FOUNDATION_PERCENTAGE % of deposits to foundation wallet.

    constructor(
        address _qstk,
        IQNFTSettings _settings,
        IQNFTGov _governance,
        address payable _foundationWallet
    ) ERC721("Quiver NFT", "QNFT") {
        qstk = _qstk;
        settings = _settings;
        governance = _governance;

        // foundation
        foundationWallet = _foundationWallet;
    }

    // qstk

    /**
     * @dev returns the total qstk balance locked on the contract
     */
    function totalQstkBalance() public view returns (uint256) {
        return IERC20(qstk).balanceOf(address(this));
    }

    /**
     * @dev returns remaining qstk balance of the contract
     */
    function remainingQstk() public view returns (uint256) {
        return totalQstkBalance().sub(totalAssignedQstk);
    }

    /**
     * @dev deposits qstk tokens to the contract
     */
    function depositQstk(uint256 _amount) public onlyOwner {
        IERC20(qstk).safeTransferFrom(msg.sender, address(this), _amount);

        emit DepositQstk(msg.sender, _amount);
    }

    /**
     * @dev withdraws qstk token from the contract - only remaing balance available
     */
    function withdrawQstk(uint256 _amount) public onlyOwner {
        require(remainingQstk() >= _amount, "QNFT: not enough balance");
        IERC20(qstk).safeTransfer(msg.sender, _amount);

        emit WithdrawQstk(msg.sender, _amount);
    }

    /**
     * @dev adds free allocation to the user
     */
    function addFreeAllocation(address _user, uint256 _amount)
        public
        onlyOwner
    {
        freeAllocations[_user] = freeAllocations[_user].add(_amount);
        totalFreeAllocations = totalFreeAllocations.add(_amount);
    }

    /**
     * @dev removes free allocation from the user
     */
    function removeFreeAllocation(address _user, uint256 _amount)
        public
        onlyOwner
    {
        if (freeAllocations[_user] > _amount) {
            totalFreeAllocations = totalFreeAllocations.sub(_amount);
            freeAllocations[_user] = freeAllocations[_user].sub(_amount);
        } else {
            totalFreeAllocations = totalFreeAllocations.sub(
                freeAllocations[_user]
            );
            freeAllocations[_user] = 0;
        }
    }

    // NFT

    /**
     * @dev returns minted nft count
     */
    function circulatingSupply() public view returns (uint256) {
        return nftCount;
    }

    /**
     * @dev sets the maximum mintable count
     */
    function setTotalSupply(uint256 _totalSupply) public onlyOwner {
        require(
            _totalSupply <
                settings.mintOptionsCount().mul(settings.nftImagesCount()).mul(
                    settings.favCoinsCount()
                ),
            "QNFT: too big"
        );

        totalSupply = _totalSupply;
        emit SetTotalSupply(msg.sender, totalSupply);
    }

    /**
     * @dev starts/restarts mint process
     */
    function startMint() public onlyOwner {
        require(
            mintStarted == false || mintFinished(),
            "QNFT: mint in progress"
        );

        mintStarted = true;
        mintStartTime = block.timestamp;

        emit StartMint(msg.sender, mintStartTime);
    }

    /**
     * @dev pause mint process
     */
    function pauseMint() public onlyOwner {
        require(mintStarted == true, "QNFT: mint not started");
        require(mintPaused == false, "QNFT: mint already paused");

        mintPaused = true;

        emit PauseMint(msg.sender, block.timestamp);
    }

    /**
     * @dev unpause mint process
     */
    function unPauseMint() public onlyOwner {
        require(mintStarted == true, "QNFT: mint not started");
        require(mintPaused == true, "QNFT: mint not paused");

        mintPaused = false;

        emit UnpauseMint(msg.sender, block.timestamp);
    }

    /**
     * @dev checks if mint process is finished
     */
    function mintFinished() public view returns (bool) {
        require(mintStarted, "QNFT: mint not started");

        return mintStartTime.add(NFT_SALE_DURATION) <= block.timestamp;
    }

    /**
     * @dev checks if min vote duration is passed
     */
    function minVoteDurationPassed() public view returns (bool) {
        require(mintFinished(), "QNFT: NFT sale not ended");

        return
            mintStartTime.add(NFT_SALE_DURATION).add(MIN_VOTE_DURATION) <=
            block.timestamp;
    }

    /**
     * @dev checks if safe vote end duration is passed
     */
    function safeVoteEndDurationPassed() public view returns (bool) {
        require(minVoteDurationPassed(), "QNFT: wait until safe vote end time");

        return
            mintStartTime.add(NFT_SALE_DURATION).add(SAFE_VOTE_END_DURATION) <=
            block.timestamp;
    }

    /**
     * @dev checks if given nft set is exists
     */
    function nftMinted(
        uint256 _imageId,
        uint256 _bgImageId,
        uint256 _favCoinId,
        uint256 _mintOptionId
    ) public view returns (bool) {
        return
            _getNftId(_imageId, _bgImageId, _favCoinId, _mintOptionId) !=
            uint256(0);
    }

    /**
     * @dev mint nft with given mint options
     */
    function mintNFT(
        uint256 _imageId,
        uint256 _bgImageId,
        uint256 _favCoinId,
        uint256 _mintOptionId,
        uint256 _mintAmount,
        uint256 _defaultImageIndex,
        string memory _name,
        string memory _creator_name,
        string memory _color,
        string memory _story
    ) public payable {
        require(mintStarted, "QNFT: mint not started");
        require(!mintPaused, "QNFT: mint paused");
        require(!mintFinished(), "QNFT: mint finished");

        // todo check mintPaused or nftsale ended
        require(
            nftCount < totalSupply,
            "QNFT: nft count reached the total supply"
        );

        require(_defaultImageIndex < 5, "QNFT: invalid image index");

        require(
            msg.value >=
                settings.calcMintPrice(
                    _imageId,
                    _bgImageId,
                    _favCoinId,
                    _mintOptionId,
                    _mintAmount,
                    freeAllocations[msg.sender]
                ),
            "QNFT: insufficient mint price"
        );

        uint256 qstkAmount = _mintAmount.add(freeAllocations[msg.sender]);

        require(
            totalAssignedQstk.add(qstkAmount) <= totalQstkBalance(),
            "QNFT: insufficient qstk balance"
        );

        require(
            !nftMinted(_imageId, _bgImageId, _favCoinId, _mintOptionId),
            "QNFT: nft already exists"
        );

        nftCount = nftCount.add(1);
        nftData[nftCount] = NFTData(
            _imageId,
            _favCoinId,
            _bgImageId,
            _mintOptionId,
            qstkAmount,
            _defaultImageIndex,
            block.timestamp,
            false,
            NFTMeta(_name, _color, _story),
            NFTCreator(_creator_name, msg.sender)
        );
        _setNftId(_imageId, _bgImageId, _favCoinId, _mintOptionId, nftCount);

        totalAssignedQstk = totalAssignedQstk.add(qstkAmount);

        uint256 originAmount = qstkBalances[msg.sender];
        qstkBalances[msg.sender] = originAmount.add(qstkAmount);

        governance.updateVoteAmount(
            msg.sender,
            originAmount,
            qstkBalances[msg.sender]
        );

        // calculate free allocations
        distributedFreeAllocations = distributedFreeAllocations.add(
            freeAllocations[msg.sender]
        );
        totalFreeAllocations = totalFreeAllocations.sub(
            freeAllocations[msg.sender]
        );
        freeAllocations[msg.sender] = 0;

        // transfer to foundation wallet
        _transferFoundation(msg.value.mul(FOUNDATION_PERCENTAGE).div(100));

        _mint(address(this), nftCount);

        emit MintNFT(
            msg.sender,
            nftCount,
            _imageId,
            _bgImageId,
            _favCoinId,
            _mintOptionId,
            _creator_name,
            _color,
            _story
        );
    }

    /**
     * @dev updates nft image of a given nft
     */
    function upgradeNftImage(uint256 _nftId, uint256 _imageId) public payable {
        require(
            _nftId != uint256(0) && nftCount >= _nftId,
            "QNFT: invalid nft id"
        );
        require(ownerOf(_nftId) == msg.sender, "QNFT: invalid owner");
        require(
            settings.nftImagesCount() >= _imageId,
            "QNFT: invalid image id"
        );

        uint256 mintPrice = settings.nftImageMintPrice(_imageId);
        require(
            msg.value >= mintPrice,
            "QNFT: insufficient image upgrade price"
        );

        uint256 oldImageId = nftData[_nftId].imageId;
        nftData[_nftId].imageId = _imageId;

        // transfer to foundation wallet
        _transferFoundation(msg.value.mul(FOUNDATION_PERCENTAGE).div(100));

        emit UpgradeNftImage(msg.sender, _nftId, oldImageId, _imageId);
    }

    /**
     * @dev updates background of a given nft
     */
    function upgradeNftBackground(uint256 _nftId, uint256 _bgImageId) public {
        require(
            _nftId != uint256(0) && nftCount >= _nftId,
            "QNFT: invalid nft id"
        );
        require(ownerOf(_nftId) == msg.sender, "QNFT: invalid owner");
        require(
            settings.bgImagesCount() >= _bgImageId,
            "QNFT: invalid background image id"
        );

        uint256 oldBgImageId = nftData[_nftId].bgImageId;
        nftData[_nftId].bgImageId = _bgImageId;

        emit UpgradeNftBackground(msg.sender, _nftId, oldBgImageId, _bgImageId);
    }

    /**
     * @dev updates favorite coin of a given nft
     */
    function upgradeNftCoin(uint256 _nftId, uint256 _favCoinId) public payable {
        require(
            _nftId != uint256(0) && nftCount >= _nftId,
            "QNFT: invalid nft id"
        );
        require(ownerOf(_nftId) == msg.sender, "QNFT: invalid owner");
        require(
            settings.favCoinsCount() >= _favCoinId,
            "QNFT: invalid image id"
        );

        uint256 mintPrice = settings.favCoinMintPrice(_favCoinId);
        require(
            msg.value >= mintPrice,
            "QNFT: insufficient coin upgrade price"
        );

        uint256 oldFavCoinId = nftData[_nftId].favCoinId;
        nftData[_nftId].favCoinId = _favCoinId;

        // transfer to foundation wallet
        _transferFoundation(msg.value.mul(FOUNDATION_PERCENTAGE).div(100));

        emit UpgradeNftCoin(msg.sender, _nftId, oldFavCoinId, _favCoinId);
    }

    /**
     * @dev unlocks/withdraws qstk from contract
     */
    function unlockQstkFromNft(uint256 _nftId) public nonReentrant {
        require(
            _nftId != uint256(0) && nftCount >= _nftId,
            "QNFT: invalid nft id"
        );
        require(ownerOf(_nftId) == msg.sender, "QNFT: invalid owner");

        NFTData storage item = nftData[_nftId];
        uint256 lockDuration =
            settings.mintOptionLockDuration(item.mintOptionId);

        require(item.unlocked == false, "QNFT: already unlocked");
        require(
            item.createdAt.add(lockDuration) >= block.timestamp,
            "QNFT: not able to unlock"
        );

        uint256 unlockAmount = item.mintAmount;
        IERC20(qstk).safeTransfer(msg.sender, unlockAmount);
        qstkBalances[msg.sender] = qstkBalances[msg.sender].sub(unlockAmount);
        totalAssignedQstk = totalAssignedQstk.sub(unlockAmount);

        item.unlocked = true;

        emit UnlockQstkFromNft(msg.sender, _nftId, unlockAmount);
    }

    // internal functions

    /**
     * @dev returns the nft id of a given mint option
     */
    function _getNftId(
        uint256 _imageId,
        uint256 _bgImageId,
        uint256 _favCoinId,
        uint256 _mintOptionId
    ) internal view returns (uint256) {
        uint256 id =
            abi
                .encodePacked(
                uint64(_imageId),
                uint64(_bgImageId),
                uint64(_favCoinId),
                uint64(_mintOptionId)
            )
                .toUint256(0);

        return nftIds[id];
    }

    /**
     * @dev sets nft id for given mint options
     */
    function _setNftId(
        uint256 _imageId,
        uint256 _bgImageId,
        uint256 _favCoinId,
        uint256 _mintOptionId,
        uint256 _nftId
    ) internal {
        uint256 id =
            abi
                .encodePacked(
                uint64(_imageId),
                uint64(_bgImageId),
                uint64(_favCoinId),
                uint64(_mintOptionId)
            )
                .toUint256(0);
        nftIds[id] = _nftId;
    }

    /**
     * @dev transfers given amount of qstk token to foundation wallet
     */
    function _transferFoundation(uint256 _amount) internal {
        // transfer to foundation wallet
        foundationWallet.transfer(_amount);
    }

    /**
     * @dev sets the foundation wallet
     */
    function setFoundationWallet(address payable _foundationWallet)
        public
        onlyOwner
    {
        require(
            foundationWallet == _foundationWallet,
            "QNFT: same foundation wallet"
        );

        foundationWallet = _foundationWallet;

        emit SetFoundationWallet(msg.sender, _foundationWallet);
    }

    /**
     * @dev transfer nft
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        super._transfer(from, to, tokenId);

        uint256 qstkAmount = nftData[tokenId].mintAmount;

        // Update QstkBalance
        qstkBalances[to] = qstkBalances[to].add(qstkAmount);
        qstkBalances[from] = qstkBalances[from].sub(qstkAmount);

        governance.updateVoteAmount(msg.sender, qstkAmount, 0);
    }
}
