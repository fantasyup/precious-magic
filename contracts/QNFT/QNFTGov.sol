// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "solidity-bytes-utils/contracts/BytesLib.sol";

import "../interface/IQNFT.sol";

/**
 * @author fantasy
 */
contract QNFTGov is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using BytesLib for bytes;

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

    // constants
    uint256 public constant VOTE_QUORUM = 50; // 50%

    // vote options
    mapping(address => uint256) voteWeights; // vote amount of give multisig wallet
    mapping(address => address) voteAddress; // vote address of given user
    mapping(address => uint256) voteWeightsByAddress; // vote amoutn of given user

    IQNFT qnft;

    modifier onlyQnft() {
        require(address(qnft) == _msgSender(), "Ownable: caller is not QNFT");
        _;
    }

    constructor() {}

    /**
     * @dev votes on a given multisig wallet with the locked qstk balance of the user
     */
    function voteGovernanceAddress(address multisig) public {
        require(qnft.mintFinished(), "QNFTGov: NFT sale not ended");

        if (voteAddress[msg.sender] != address(0x0)) {
            // remove previous vote
            voteWeights[voteAddress[msg.sender]] = voteWeights[
                voteAddress[msg.sender]
            ]
                .sub(voteWeightsByAddress[msg.sender]);
        }

        uint256 qstkAmount = qnft.qstkBalances(msg.sender);
        voteWeights[multisig] = voteWeights[multisig].add(qstkAmount);
        voteWeightsByAddress[msg.sender] = qstkAmount;
        voteAddress[msg.sender] = multisig;

        emit VoteGovernanceAddress(msg.sender, multisig, qstkAmount);
    }

    /**
     * @dev withdraws to the governance address if it has enough vote amount
     */
    function withdrawToGovernanceAddress(address payable multisig)
        public
        nonReentrant
    {
        require(qnft.minVoteDurationPassed(), "QNFTGov: in vote process");

        require(
            voteWeights[multisig] >=
                qnft.totalAssignedQstk().mul(VOTE_QUORUM).div(100),
            "QNFTGov: specified multisig address is not voted enough"
        );

        uint256 amount = address(this).balance;

        multisig.transfer(amount);

        emit WithdrawToGovernanceAddress(msg.sender, multisig, amount);
    }

    /**
     * @dev withdraws to multisig wallet by owner - need to pass the safe vote end duration
     */
    function safeWithdraw(address payable multisig)
        public
        onlyOwner
        nonReentrant
    {
        require(
            qnft.safeVoteEndDurationPassed(),
            "QNFTGov: wait until safe vote end time"
        );

        uint256 amount = address(this).balance;

        multisig.transfer(amount);

        emit SafeWithdraw(msg.sender, multisig, amount);
    }

    /**
     * @dev updates the votes amount of the given user
     */
    function updateVoteAmount(
        address user,
        uint256 originAmount,
        uint256 newAmount
    ) public onlyQnft {
        if (voteAddress[user] != address(0x0)) {
            // just updates the vote amount if the user has previous vote.

            voteWeightsByAddress[user] = voteWeightsByAddress[user]
                .sub(originAmount)
                .add(newAmount);

            voteWeights[voteAddress[msg.sender]] = voteWeights[
                voteAddress[msg.sender]
            ]
                .sub(originAmount)
                .add(newAmount);

            if (voteWeightsByAddress[user] == 0) {
                voteAddress[user] = address(0x0);
            }
        }
    }

    /**
     * @dev sets QNFT contract address
     */
    function setQNft(IQNFT _qnft) public onlyOwner {
        require(qnft != _qnft, "QNFTSettings: QNFT already set");

        qnft = _qnft;
    }
}
