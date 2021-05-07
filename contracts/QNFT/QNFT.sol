// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "solidity-bytes-utils/contracts/BytesLib.sol";

import "./QNFTSettings.sol";

/**
 * @author fantasy
 */
contract QNFT is Ownable, ERC721 {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using BytesLib for bytes;

    // structs
    struct NFTMeta {
        string name; // TODO: NFT should have name
        string creator_name; // TODO: should name this to creator name
        address creator;
        string color;
        string story;
    }
    struct NFTData {
        uint256 imageId;
        uint256 bgImageId;
        uint256 favCoinId;
        uint256 mintOptionId;
        uint256 mintAmount;
        uint256 createdAt;
        bool unlocked;
        NFTMeta meta;
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
        string author,
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
    event VoteGovernanceAddress(
        address indexed voter,
        address indexed multisig,
        uint256 amount
    );
    event WithdrawToGovernanceAddress(
        address indexed user,
        address indexed multisig,
        uint256 amount
    );
    event SafeWithdraw(
        address indexed owner,
        address indexed ultisig,
        uint256 amount
    );
    event SetFoundationWallet(address indexed owner, address wallet);

    // constants
    uint256 public constant NFT_SALE_DURATION = 1209600; // 2 weeks
    uint256 public constant FOUNDATION_PERCENTAGE = 40; // 40%
    uint256 public constant MIN_VOTE_DURATION = 604800; // 1 week
    uint256 public constant SAFE_VOTE_END_DURATION = 1814400; // 3 weeks
    uint256 public constant VOTE_QUORUM = 50; // 50%

    // qstk
    address public qstk;
    uint256 public totalAssignedQstk; // total qstk balance assigned to nfts
    mapping(address => uint256) public qstkBalances;
    mapping(address => uint256) public freeAllocations;

    // nft
    QNFTSettings settings;
    uint256 public totalSupply; // maximum mintable nft count
    mapping(uint256 => NFTData) public nftData;
    mapping(uint256 => uint256) private nftId;
    uint256 nftCount;

    // mint options set
    bool public mintStarted;
    uint256 public mintStartTime;
    bool public mintPaused;

    // vote options
    mapping(address => uint256) voteWeights;
    mapping(address => address) voteAddress;
    mapping(address => uint256) voteWeightsByAddress;

    // foundation
    address payable public foundationWallet;

    constructor(
        address _qstk,
        QNFTSettings _settings,
        address payable _foundationWallet
    ) ERC721("Quiver NFT", "QNFT") {
        qstk = _qstk;
        settings = _settings;

        // foundation
        foundationWallet = _foundationWallet;
    }

    // qstk
    function totalQstkBalance() public view returns (uint256) {
        return IERC20(qstk).balanceOf(address(this));
    }

    function remainingQstk() public view returns (uint256) {
        return totalQstkBalance().sub(totalAssignedQstk);
    }

    function depositQstk(uint256 _amount) public onlyOwner {
        IERC20(qstk).safeTransferFrom(msg.sender, address(this), _amount);

        emit DepositQstk(msg.sender, _amount);
    }

    function withdrawQstk(uint256 _amount) public onlyOwner {
        require(remainingQstk() >= _amount, "QNFT: not enough balance");
        IERC20(qstk).safeTransfer(msg.sender, _amount);

        emit WithdrawQstk(msg.sender, _amount);
    }

    // TODO: should add getFreeAllocation
    // TODO: should add maxFreeAllocation and manage free allocation current supply
    // TODO: should add distributedFreeAllocation
    
    function addFreeAllocation(address _user, uint256 _amount)
        public
        onlyOwner
    {
        freeAllocations[_user] = freeAllocations[_user].add(_amount);
    }

    function removeFreeAllocation(address _user, uint256 _amount)
        public
        onlyOwner
    {
        if (freeAllocations[_user] > _amount) {
            freeAllocations[_user] = freeAllocations[_user].sub(_amount);
        } else {
            freeAllocations[_user] = 0;
        }
    }

    // nft
    function circulatingSupply() public view returns (uint256) {
        return nftCount;
    }

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

    function isNftMinted(
        uint256 _imageId,
        uint256 _bgImageId,
        uint256 _favCoinId,
        uint256 _mintOptionId
    ) public view returns (bool) {
        return
            _getNftId(_imageId, _bgImageId, _favCoinId, _mintOptionId) !=
            uint256(0);
    }

    function mintNFT(
        uint256 _imageId,
        uint256 _bgImageId,
        uint256 _favCoinId,
        uint256 _mintOptionId,
        uint256 _mintAmount,
        string memory _author,
        string memory _color,
        string memory _story
    ) public payable {
        require(mintStarted == true, "QNFT: mint not started");
        require(
            nftCount < totalSupply,
            "QNFT: nft count reached the total supply"
        );

        // TODO: should select default image index for listing
        // TODO: should add field on NFTMeta for this

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
            !isNftMinted(_imageId, _bgImageId, _favCoinId, _mintOptionId),
            "QNFT: nft already exists"
        );

        nftCount = nftCount.add(1);
        nftData[nftCount] = NFTData(
            _imageId,
            _favCoinId,
            _bgImageId,
            _mintOptionId,
            qstkAmount,
            block.timestamp,
            false,
            NFTMeta(_author, msg.sender, _color, _story)
        );
        _setNftId(_imageId, _bgImageId, _favCoinId, _mintOptionId, nftCount);

        totalAssignedQstk = totalAssignedQstk.add(qstkAmount);
        qstkBalances[msg.sender] = qstkBalances[msg.sender].add(qstkAmount);
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
            _author,
            _color,
            _story
        );
    }

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

        (uint256 mintPrice, , , , , ) = settings.nftImages(_imageId);
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

    function upgradeNftBackground(uint256 _nftId, uint256 _bgImageId)
        public
        payable
    {
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

        (uint256 mintPrice, , , , , , , ) = settings.favCoins(_favCoinId);
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

    function unlockQstkFromNft(uint256 _nftId) public {
        require(
            _nftId != uint256(0) && nftCount >= _nftId,
            "QNFT: invalid nft id"
        );
        require(ownerOf(_nftId) == msg.sender, "QNFT: invalid owner");

        NFTData storage item = nftData[_nftId];
        (, , uint256 lockDuration, ) = settings.mintOptions(item.mintOptionId);

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

    function voteGovernanceAddress(address multisig) public {
        require(mintStarted, "QNFT: mint not started");
        require(
            mintStartTime.add(NFT_SALE_DURATION) <= block.timestamp,
            "QNFT: NFT sale not ended"
        );

        if (voteAddress[msg.sender] != address(0x0)) {
            // remove previous vote
            voteWeights[voteAddress[msg.sender]] = voteWeights[
                voteAddress[msg.sender]
            ]
                .sub(voteWeightsByAddress[msg.sender]);
        }
        voteWeights[multisig] = voteWeights[multisig].add(
            qstkBalances[msg.sender]
        );
        voteWeightsByAddress[msg.sender] = qstkBalances[msg.sender];
        voteAddress[msg.sender] = multisig;

        emit VoteGovernanceAddress(
            msg.sender,
            multisig,
            qstkBalances[msg.sender]
        );
    }

    function withdrawToGovernanceAddress(address payable multisig) public {
        require(mintStarted, "QNFT: mint not started");
        require(
            mintStartTime.add(NFT_SALE_DURATION) <= block.timestamp,
            "QNFT: NFT sale not ended"
        );
        require(
            mintStartTime.add(NFT_SALE_DURATION).add(MIN_VOTE_DURATION) <=
                block.timestamp,
            "QNFT: in vote process"
        );

        require(
            voteWeights[multisig] >=
                totalAssignedQstk.mul(VOTE_QUORUM).div(100),
            "QNFT: specified multisig address is not voted enough"
        );

        uint256 amount = address(this).balance;
        multisig.transfer(address(this).balance);

        emit WithdrawToGovernanceAddress(msg.sender, multisig, amount);
    }

    function safeWithdraw(address payable multisig) public onlyOwner {
        require(mintStarted, "QNFT: mint not started");
        require(
            mintStartTime.add(NFT_SALE_DURATION) <= block.timestamp,
            "QNFT: NFT sale not ended"
        );
        require(
            mintStartTime.add(NFT_SALE_DURATION).add(MIN_VOTE_DURATION) <=
                block.timestamp,
            "QNFT: in vote process"
        );
        require(
            mintStartTime.add(NFT_SALE_DURATION).add(SAFE_VOTE_END_DURATION) <=
                block.timestamp,
            "QNFT: wait until safe vote end time"
        );

        uint256 amount = address(this).balance;
        multisig.transfer(address(this).balance);

        emit SafeWithdraw(msg.sender, multisig, amount);
    }

    // internal functions
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

        return nftId[id];
    }

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
        nftId[id] = _nftId;
    }

    function _transferFoundation(uint256 _amount) internal {
        // transfer to foundation wallet
        foundationWallet.transfer(_amount);
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

    // TODO: NFT transfer is not implemented
    // - NFT transfer should change below
    // 1. Update owner
    // 2. Update QstkBalance variable
    // 3. Upate Vote result of NFT transfer
    // 4. All the other variables that is related to owner
    // 5. Add tests for all of changes that need to be made from NFT transfer
}
