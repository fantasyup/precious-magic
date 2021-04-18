// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";

contract QStk is Ownable, ERC20PresetFixedSupply {
    using SafeMath for uint256;

    event AddBlacklistedUser(address indexed _user);
    event RemoveBlacklistedUser(address indexed _user);

    mapping(address => bool) public isBlacklisted;

    constructor(uint256 _initialSupply, address _owner)
        ERC20PresetFixedSupply("Quiver Stock", "QSTK", _initialSupply, _owner)
    {}

    function addBlacklistedUser(address _user) public onlyOwner {
        require(isBlacklisted[_user] != true, "QStk: already in blacklist");

        isBlacklisted[_user] = true;

        emit AddBlacklistedUser(_user);
    }

    function removeBlacklistedUser(address _user) public onlyOwner {
        require(isBlacklisted[_user] == true, "QStk: not in blacklist");

        isBlacklisted[_user] = false;

        emit RemoveBlacklistedUser(_user);
    }

    // Internal functions

    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal override {
        // blacklisted users can't transfer tokens

        require(isBlacklisted[_from] != true, "QStk: sender is in blacklist");
        require(isBlacklisted[_to] != true, "QStk: receiver is in blacklist");
        require(_amount != 0, "QStk: non-zero amount is required");

        super._beforeTokenTransfer(_from, _to, _amount);
    }
}
