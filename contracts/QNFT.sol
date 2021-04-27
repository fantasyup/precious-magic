// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "solidity-bytes-utils/contracts/BytesLib.sol";

import "./QBaseNFT.sol";

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
    event SetTotalSupply(address indexed owner, uint256 totalSupply);

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
    }

    function withdrawQstk(uint256 _amount) public onlyOwner {
        require(remainingQstk() >= _amount, "QNFT: not enough balance");
        IERC20(qstk).safeTransfer(msg.sender, _amount);
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

        uint256 qstkAmount = mintOptions[_mintOptionId].ownableAmount;

        require(
            totalAssignedQstk + qstkAmount <= totalSupply,
            "QNFT: insufficient qstk balance"
        );

        uint256 discount = mintOptions[_mintOptionId].discount;

        uint256 mintPrice =
            ((initialSalePrice * qstkAmount * discount) / 100) +
                nftImages[_imageId].price +
                favCoins[_favCoinId].price;

        require(msg.value >= mintPrice, "QNFT: insufficient mint price");

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
    }

    function upgradeNftImage(uint256 _nftId, uint256 _imageId) public payable {
        require(
            _nftId != uint256(0) && nftCount >= _nftId,
            "QNFT: invalid nft id"
        );
        require(ownerOf(_nftId) == msg.sender, "QNFT: invalid owner");
        require(nftImages.length >= _imageId, "QNFT: invalid image id");
        require(
            msg.value >= nftImages[_imageId].price,
            "QNFT: insufficient image upgrade price"
        );

        nftData[_nftId].imageId = _imageId;

        // transfer to foundation wallet
        _transferFoundation((msg.value * FOUNDATION_PERCENTAGE) / 100);
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

        nftData[_nftId].bgImageId = _bgImageId;
    }

    function upgradeNftCoin(uint256 _nftId, uint256 _favCoinId) public payable {
        require(
            _nftId != uint256(0) && nftCount >= _nftId,
            "QNFT: invalid nft id"
        );
        require(ownerOf(_nftId) == msg.sender, "QNFT: invalid owner");
        require(favCoins.length >= _favCoinId, "QNFT: invalid image id");
        require(
            msg.value >= favCoins[_favCoinId].price,
            "QNFT: insufficient coin upgrade price"
        );

        nftData[_nftId].favCoinId = _favCoinId;

        // transfer to foundation wallet
        _transferFoundation((msg.value * FOUNDATION_PERCENTAGE) / 100);
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
    }

    function voteGovernanceAddress(address multisig) public {
        require(mintStarted, "QNFT: mint not started");
        require(
            mintStartTime + NFT_SALE_DURATION <= block.timestamp,
            "QNFT: NFT sale not ended"
        );

        if (voteAddress[msg.sender] != address(0x0)) {
            // remove previous vote
            voteWeights[voteAddress[msg.sender]] -= qstkBalances[msg.sender];
        }
        voteWeights[multisig] += qstkBalances[msg.sender];
        voteAddress[msg.sender] = multisig;
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

        multisig.transfer(address(this).balance);
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

        multisig.transfer(address(this).balance);
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
