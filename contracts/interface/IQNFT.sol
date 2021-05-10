// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "./structs.sol";

interface IQNFT {
    function qstk() external view returns (address);

    function mintStarted() external view returns (bool);

    function mintFinished() external view returns (bool);

    function voteStatus() external view returns (VoteStatus);

    function qstkBalances(address user) external view returns (uint256);

    function totalAssignedQstk() external view returns (uint256);
}
