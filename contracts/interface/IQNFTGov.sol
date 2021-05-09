// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface IQNFTGov {
    function updateVoteAmount(
        address user,
        uint256 originAmount,
        uint256 newAmount
    ) external;
}
