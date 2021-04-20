// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/**
 * Quiver Reputation Contract
 * @author fantasy
 *
 * initial supply on contact creation.
 * whitelisted users can transfer for initial community setup period.
 * blacklisted users can't make any action and QRep balance.
 *
 * only owner can mint tokens - owner should be multisig address after initial setup.
 * anyone can burn his/her tokens + only owner can burn amyone's tokens.
 */

// TODO: add events

contract QRep is Ownable, ERC20Burnable {
    using SafeMath for uint256;

    event AddWhitelistedUser(address indexed _user);
    event RemoveWhitelistedUser(address indexed _user);
    event AddBlacklistedUser(address indexed _user);
    event RemoveBlacklistedUser(address indexed _user);

    bool public enableTransferForWhitelistedUsers;
    mapping(address => bool) public isWhitelisted;
    mapping(address => bool) public isBlacklisted;

    constructor(uint256 _initialSupply) ERC20("Quiver Reputation", "QRep") {
        mint(msg.sender, _initialSupply);
        isWhitelisted[msg.sender] = true;
        enableTransferForWhitelistedUsers = true;
    }

    function addWhitelistedUser(address _user) public onlyOwner {
        require(isWhitelisted[_user] != true, "QRep: already in whitelist");

        isWhitelisted[_user] = true;

        emit AddWhitelistedUser(_user);
    }

    function removeWhitelistedUser(address _user) public onlyOwner {
        require(isWhitelisted[_user] == true, "QRep: not in whitelist");

        isWhitelisted[_user] = false;

        emit RemoveWhitelistedUser(_user);
    }

    function addBlacklistedUser(address _user) public onlyOwner {
        require(isBlacklisted[_user] != true, "QRep: already in blacklist");

        isBlacklisted[_user] = true;
        _burn(_user, balanceOf(_user));

        emit AddBlacklistedUser(_user);
    }

    function removeBlacklistedUser(address _user) public onlyOwner {
        require(isBlacklisted[_user] == true, "QRep: not in blacklist");

        isBlacklisted[_user] = false;

        emit RemoveBlacklistedUser(_user);
    }

    function setEnableTransferForWhitelistedUsers(
        bool _enableTransferForWhitelistedUsers
    ) public onlyOwner {
        enableTransferForWhitelistedUsers = _enableTransferForWhitelistedUsers;
    }

    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }

    function burnByOwner(address account, uint256 amount) public onlyOwner {
        _burn(account, amount);
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
                isBlacklisted[_to] == false,
                "QRep: target address is in blacklist"
            );
        } else if (_to == address(0)) {
            // burn
        } else {
            // only initial sender can transfer tokens
            require(
                enableTransferForWhitelistedUsers == true &&
                    isWhitelisted[_from] == true,
                "QRep: sender address is not in whitelist"
            );
            require(
                enableTransferForWhitelistedUsers == false && _from == owner(),
                "QRep: sender address is not owner"
            );
            require(
                isBlacklisted[_from] == false,
                "QRep: sender address is in blacklist"
            );
            require(
                isBlacklisted[_to] == false,
                "QRep: target address is in blacklist"
            );
            require(_amount != 0, "QRep: non-zero amount is required");
        }

        super._beforeTokenTransfer(_from, _to, _amount);
    }
}
