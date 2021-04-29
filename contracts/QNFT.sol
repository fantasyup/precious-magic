// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "solidity-bytes-utils/contracts/BytesLib.sol";

import "./QBaseNFT.sol";

/**
 * @author fantasy
 */
contract QNFT is ERC721, QBaseNFT {
    using SafeERC20 for IERC20;
    using BytesLib for bytes;

    // structs
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
        uint256 bgImageId;
        uint256 favCoinId;
        uint256 mintOptionId;
        NFTMeta meta;
    }

    // events
    event DepositQstk(address indexed owner, uint256 amount);
    event WithdrawQstk(address indexed owner, uint256 amount);
    event SetTotalSupply(address indexed owner, uint256 totalSupply);
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

    // qstk
    address public qstk;
    uint256 public totalAssignedQstk; // total qstk balance assigned to nfts
    mapping(address => uint256) public qstkBalances;

    // nft
    uint256 public totalSupply; // maximum mintable nft count
    mapping(uint256 => NFTData) public nftData;
    mapping(uint256 => uint256) private nftId;
    uint256 nftCount;

    constructor(address _qstk, address payable _foundationWallet)
        ERC721("Quiver NFT", "QNFT")
        QBaseNFT(_foundationWallet)
    {
        qstk = _qstk;
    }

    // qstk
    function totalQstkBalance() public view returns (uint256) {
        return IERC20(qstk).balanceOf(address(this));
    }

    function remainingQstk() public view returns (uint256) {
        return totalQstkBalance() - totalAssignedQstk;
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

    // nft
    function circulatingSupply() public view returns (uint256) {
        return nftCount;
    }

    function setTotalSupply(uint256 _totalSupply) public onlyOwner {
        require(
            _totalSupply <
                mintOptions.length * nftImages.length * favCoins.length,
            "QNFT: too big"
        );

        totalSupply = _totalSupply;
        emit SetTotalSupply(msg.sender, totalSupply);
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

    function mintPrice(
        uint256 _imageId,
        uint256 _bgImageId,
        uint256 _favCoinId,
        uint256 _mintOptionId
    ) public view returns (uint256) {
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
            ((((initialSalePrice *
                mintOptions[_mintOptionId].ownableAmount *
                mintOptions[_mintOptionId].discount) / 100) +
                nftImages[_imageId].mintPrice +
                favCoins[_favCoinId].mintPrice) * mintPriceMultiplier) / 100;
    }

    function mintNFT(
        uint256 _imageId,
        uint256 _bgImageId,
        uint256 _favCoinId,
        uint256 _mintOptionId,
        string memory _author,
        string memory _color,
        string memory _story
    ) public payable {
        require(mintStarted == true, "QNFT: mint not started");
        require(
            nftCount < totalSupply,
            "QNFT: nft count reached the total supply"
        );

        require(
            msg.value >=
                mintPrice(_imageId, _bgImageId, _favCoinId, _mintOptionId),
            "QNFT: insufficient mint price"
        );

        uint256 qstkAmount = mintOptions[_mintOptionId].ownableAmount;

        require(
            totalAssignedQstk + qstkAmount <= totalSupply,
            "QNFT: insufficient qstk balance"
        );

        require(
            !isNftMinted(_imageId, _bgImageId, _favCoinId, _mintOptionId),
            "QNFT: nft already exists"
        );

        nftCount = nftCount + 1;
        nftData[nftCount] = NFTData(
            _imageId,
            _favCoinId,
            _bgImageId,
            _mintOptionId,
            NFTMeta(_author, msg.sender, _color, _story, block.timestamp, false)
        );
        _setNftId(_imageId, _bgImageId, _favCoinId, _mintOptionId, nftCount);

        totalAssignedQstk = totalAssignedQstk + qstkAmount;
        qstkBalances[msg.sender] = qstkBalances[msg.sender] + qstkAmount;

        // transfer to foundation wallet
        _transferFoundation((msg.value * FOUNDATION_PERCENTAGE) / 100);

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
        require(nftImages.length >= _imageId, "QNFT: invalid image id");
        require(
            msg.value >= nftImages[_imageId].mintPrice,
            "QNFT: insufficient image upgrade price"
        );

        uint256 oldImageId = nftData[_nftId].imageId;
        nftData[_nftId].imageId = _imageId;

        // transfer to foundation wallet
        _transferFoundation((msg.value * FOUNDATION_PERCENTAGE) / 100);

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
            bgImages.length >= _bgImageId,
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
        require(favCoins.length >= _favCoinId, "QNFT: invalid image id");
        require(
            msg.value >= favCoins[_favCoinId].mintPrice,
            "QNFT: insufficient coin upgrade price"
        );

        uint256 oldFavCoinId = nftData[_nftId].favCoinId;
        nftData[_nftId].favCoinId = _favCoinId;

        // transfer to foundation wallet
        _transferFoundation((msg.value * FOUNDATION_PERCENTAGE) / 100);

        emit UpgradeNftCoin(msg.sender, _nftId, oldFavCoinId, _favCoinId);
    }

    function unlockQstkFromNft(uint256 _nftId) public {
        require(
            _nftId != uint256(0) && nftCount >= _nftId,
            "QNFT: invalid nft id"
        );
        require(ownerOf(_nftId) == msg.sender, "QNFT: invalid owner");

        NFTData storage item = nftData[_nftId];
        MintOption memory mintOption = mintOptions[item.mintOptionId];

        require(item.meta.unlocked == false, "QNFT: already unlocked");
        require(
            item.meta.createdAt + mintOption.lockDuration >= block.timestamp,
            "QNFT: not able to unlock"
        );

        uint256 unlockAmount = mintOption.ownableAmount;
        IERC20(qstk).safeTransfer(msg.sender, unlockAmount);
        qstkBalances[msg.sender] = qstkBalances[msg.sender] - unlockAmount;
        totalAssignedQstk = totalAssignedQstk - unlockAmount;

        item.meta.unlocked = true;

        emit UnlockQstkFromNft(msg.sender, _nftId, unlockAmount);
    }

    function voteGovernanceAddress(address multisig) public {
        require(mintStarted, "QNFT: mint not started");
        require(
            mintStartTime + NFT_SALE_DURATION <= block.timestamp,
            "QNFT: NFT sale not ended"
        );

        if (voteAddress[msg.sender] != address(0x0)) {
            // remove previous vote
            voteWeights[voteAddress[msg.sender]] -= voteWeightsByAddress[
                msg.sender
            ];
        }
        voteWeights[multisig] += qstkBalances[msg.sender];
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
            mintStartTime + NFT_SALE_DURATION <= block.timestamp,
            "QNFT: NFT sale not ended"
        );
        require(
            mintStartTime + NFT_SALE_DURATION + MIN_VOTE_DURATION <=
                block.timestamp,
            "QNFT: in vote process"
        );

        require(
            voteWeights[multisig] >= (totalAssignedQstk * VOTE_QUORUM) / 100,
            "QNFT: specified multisig address is not voted enough"
        );

        uint256 amount = address(this).balance;
        multisig.transfer(address(this).balance);

        emit WithdrawToGovernanceAddress(msg.sender, multisig, amount);
    }

    function safeWithdraw(address payable multisig) public onlyOwner {
        require(mintStarted, "QNFT: mint not started");
        require(
            mintStartTime + NFT_SALE_DURATION <= block.timestamp,
            "QNFT: NFT sale not ended"
        );
        require(
            mintStartTime + NFT_SALE_DURATION + MIN_VOTE_DURATION <=
                block.timestamp,
            "QNFT: in vote process"
        );
        require(
            mintStartTime + NFT_SALE_DURATION + SAFE_VOTE_END_DURATION <=
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
}
