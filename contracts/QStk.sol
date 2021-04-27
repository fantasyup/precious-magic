// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/**
 * Quiver Stock Contract
 * @author fantasy
 *
 * initial supply on contact creation.
 * blacklisted users can't make any action and QStk balance.
 *
 * only minters can mint tokens - owner should be able to add/remove minters. (Minters should be be invester contracts.)
 * owner should be multisig address of governance after initial setup.
 * anyone can burn his/her tokens.
 */

contract QStk is Ownable, ERC20PresetMinterPauser {
    using SafeMath for uint256;

    event AddBlacklistedUser(address indexed _user);
    event RemoveBlacklistedUser(address indexed _user);

    mapping(address => bool) public isBlacklisted;

    constructor(uint256 _initialSupply)
        ERC20PresetMinterPauser("Quiver Stock", "QSTK")
    {
        mint(msg.sender, _initialSupply);
        revokeRole(MINTER_ROLE, msg.sender);
    }

    function addBlacklistedUser(address _user) public onlyOwner {
        require(isBlacklisted[_user] != true, "QStk: already in blacklist");

        isBlacklisted[_user] = true;

        emit AddBlacklistedUser(_user);
    }

    function removeBlacklistedUser(address _user) public onlyOwner {
        require(isBlacklisted[_user] == true, "QStk: not in blacklist");

        isBlacklisted[_user] = false;
        _burn(_user, balanceOf(_user));

        emit RemoveBlacklistedUser(_user);
    }

    function addMinter(address _minter) public onlyOwner {
        _setupRole(MINTER_ROLE, _minter);
    }

    function removeMinter(address _minter) public onlyOwner {
        revokeRole(MINTER_ROLE, _minter);
    }

    // Internal functions

    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal override {
        if (_from == address(0)) {
            // mint
            require(
                isBlacklisted[_to] != true,
                "QStk: target address is in blacklist"
            );
        } else if (_to == address(0)) {
            // burn
        } else {
            // blacklisted users can't transfer tokens
            require(
                isBlacklisted[_from] != true,
                "QStk: sender address is in blacklist"
            );
            require(
                isBlacklisted[_to] != true,
                "QStk: target address is in blacklist"
            );
            require(_amount != 0, "QStk: non-zero amount is required");
        }

        super._beforeTokenTransfer(_from, _to, _amount);
    }
}
