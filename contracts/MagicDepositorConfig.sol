// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import '@openzeppelin/contracts/access/Ownable.sol';

contract MagicDepositorConfig is Ownable {
    event UpdatedConfiguration(uint256 stakeRewardSplit, uint256 treasurySplit, address treasury, address staking);

    /** Config variables */
    uint256 public stakeRewardSplit; // Proportion of harvest that is going to stake rewards
    uint256 public treasurySplit; // Proportion of harvest that goes to the treasury
    address public treasury; // Address of the treasury
    address public staking; // Address of the staking contract

    /** ACCESS-CONTROLLED FUNCTIONS */

    function setConfig(
        uint256 _stakeRewardSplit,
        uint256 _treasurySplit,
        address _treasury,
        address _staking
    ) external onlyOwner {
        require(_stakeRewardSplit + _treasurySplit < 1 ether, 'Invalid split config');
        require(_treasury != address(0), 'Invalid treasury addr');
        require(_staking != address(0), 'Invalid staking addr');

        stakeRewardSplit = _stakeRewardSplit;
        treasurySplit = _treasurySplit;
        treasury = _treasury;
        staking = _staking;

        emit UpdatedConfiguration(_stakeRewardSplit, _treasurySplit, _treasury, _staking);
    }
}
