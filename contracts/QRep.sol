// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";

contract QRep is Ownable, ERC20PresetFixedSupply {
    using SafeMath for uint256;

    address initialSender;

    constructor(uint256 _initialSupply, address _owner)
        ERC20PresetFixedSupply(
            "Quiver Reputation",
            "QRep",
            _initialSupply,
            _owner
        )
    {
        initialSender = _owner;
    }

    // Internal functions

    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal override {
        // only initial sender can transfer tokens
        require(_from == initialSender, "QStk: not initial sender");
        require(_amount != 0, "QStk: non-zero amount is required");

        super._beforeTokenTransfer(_from, _to, _amount);
    }
}
