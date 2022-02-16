// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import '@openzeppelin/contracts/utils/Address.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import './MAGIC/IAtlasMine.sol';

import './mgMagicToken.sol';
import { AtlasDeposit, AtlasDepositLibrary } from './libs/AtlasDeposit.sol';
import './MagicDepositorConfig.sol';

contract MagicDepositor is MagicDepositorConfig {
    using SafeERC20 for IERC20;
    using AtlasDepositLibrary for AtlasDeposit;

    uint8 private constant LOCK_FOR_TWELVE_MONTH = 4;
    uint256 private constant ONE_MONTH = 30 days;
    uint256 private constant PRECISION = 1e18;

    IERC20 private immutable magic;
    mgMagicToken private immutable mgMagic;
    IAtlasMine private immutable atlasMine;

    mapping(uint256 => AtlasDeposit) public _atlasDeposits;

    /** State variables */
    uint256 private currentAtlasDepositIndex; // Most recent accumulated atlasDeposit
    uint256 private harvestForNextDeposit; // Accumulated magic through harvest that is going to be recompounded on the next atlasDeposit
    uint256 private harvestForStakeRewards; // " " that is going to be used to reward stakers
    uint256 private harvestForTreasury; // " " that is going to sent to the treasury for other operations
    uint256 private heldMagic; // Internal accounting that determines the amount of shares to mint on each atlasDeposit operation

    constructor(
        address _magic,
        address _mgMagic,
        address _atlasMine
    ) {
        magic = IERC20(_magic);
        mgMagic = mgMagicToken(_mgMagic);
        atlasMine = IAtlasMine(_atlasMine);
    }

    /** USER EXPOSED FUNCTIONS */

    function deposit(uint256 amount) external {
        _depositFor(amount, msg.sender);
    }

    function depositFor(uint256 amount, address to) external {
        _depositFor(amount, to);
    }

    function claimMintedShares(uint256 atlasDepositIndex) external returns (uint256) {
        AtlasDeposit storage atlasDeposit = _atlasDeposits[atlasDepositIndex];
        require(atlasDeposit.exists, 'Deposit does not exist');
        require(atlasDeposit.isActive, 'Deposit has not been activated yet');

        uint256 claim = (atlasDeposit.depositedMagicPerAddress[msg.sender] * atlasDeposit.mintedShares) /
            atlasDeposit.accumulatedMagic;
        require(claim > 0, 'Nothing to claim');

        atlasDeposit.depositedMagicPerAddress[msg.sender] = 0;
        mgMagic.transfer(msg.sender, claim);
        return claim;
    }

    function withdrawStakeRewards() external {
        uint256 amount = harvestForStakeRewards;
        harvestForStakeRewards = 0;
        magic.transfer(staking, amount);
    }

    function withdrawTreasury() external {
        uint256 amount = harvestForTreasury;
        harvestForTreasury = 0;
        magic.transfer(treasury, amount);
    }

    /** INTERNAL FUNCTIONS */

    function _depositFor(uint256 amount, address to) internal {
        require(amount > 0, 'amount cannot be 0');
        require(to != address(0), 'cannot atlasDeposit to 0x0');

        _updateAtlasDeposits();
        _checkCurrentDeposit().increaseMagic(amount, to);
        magic.safeTransferFrom(msg.sender, address(this), amount);
    }

    function _updateAtlasDeposits() internal {
        uint256 withdrawnAmount = _withdraw(); // Need to check this first so that deposits are removed on the harvest call @ mine
        uint256 harvestedAmount = _harvest();

        uint256 stakeRewardIncrement = (harvestedAmount * stakeRewardSplit) / PRECISION;
        uint256 treasuryIncrement = (harvestedAmount * treasurySplit) / PRECISION;
        uint256 heldMagicIncrement = withdrawnAmount + harvestedAmount - stakeRewardIncrement - treasuryIncrement;

        harvestForStakeRewards += stakeRewardIncrement;
        harvestForTreasury += treasuryIncrement;
        heldMagic += heldMagicIncrement;

        harvestForNextDeposit += heldMagicIncrement;
    }

    function _checkCurrentDeposit() internal returns (AtlasDeposit storage) {
        AtlasDeposit storage atlasDeposit = _atlasDeposits[currentAtlasDepositIndex];
        if (!atlasDeposit.exists) return _initializeNewAtlasDeposit();
        if (!atlasDeposit.isActive) {
            _activateDeposit(atlasDeposit);
            return _initializeNewAtlasDeposit();
        }

        return atlasDeposit;
    }

    /// @dev this function should be called after _withdraw() to maintain this contract in sync
    /// with the AtlasMine
    function _harvest() internal returns (uint256 magicBalanceIncrement) {
        uint256 magicBalancePreUpdate = magic.balanceOf(address(this));
        atlasMine.harvestAll();

        magicBalanceIncrement = magic.balanceOf(address(this)) - magicBalancePreUpdate;
    }

    function _withdraw() internal returns (uint256 magicBalanceWithdrawn) {
        uint256 magicBalancePreUpdate = magic.balanceOf(address(this));
        unchecked {
            uint256[] memory depositIds = atlasMine.getAllUserDepositIds(address(this));
            for (uint256 i = 0; i < depositIds.length; i++) {
                uint256 depositId = depositIds[i];

                (, , , uint256 lockTimestamp, , , ) = atlasMine.userInfo(address(this), depositId);
                if (lockTimestamp < block.timestamp) atlasMine.withdrawPosition(depositId, type(uint256).max);
            }
        }
        return magic.balanceOf(address(this)) - magicBalancePreUpdate;
    }

    function _initializeNewAtlasDeposit() internal returns (AtlasDeposit storage atlasDeposit) {
        atlasDeposit = _atlasDeposits[currentAtlasDepositIndex++];
        atlasDeposit.exists = true;
        atlasDeposit.activationTimestamp = block.timestamp + ONE_MONTH;
        return atlasDeposit;
    }

    function _activateDeposit(AtlasDeposit storage atlasDeposit) internal {
        atlasDeposit.isActive = true;
        uint256 accumulatedMagic = atlasDeposit.accumulatedMagic;

        uint256 mintedShares = (accumulatedMagic * mgMagic.totalSupply()) / heldMagic;
        atlasDeposit.mintedShares = mintedShares;
        heldMagic += accumulatedMagic;

        mgMagic.mint(address(this), mintedShares);

        uint256 depositAmount = accumulatedMagic + harvestForNextDeposit;
        magic.approve(address(atlasMine), depositAmount);
        harvestForNextDeposit = 0;
        atlasMine.deposit(depositAmount, LOCK_FOR_TWELVE_MONTH);
    }
}
