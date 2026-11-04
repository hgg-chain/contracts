// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract GJZ is ERC20 {
    address public immutable controller;
    error ControllerOnly();
    error NonTransferable();
    error InvalidAddress();

    constructor(address power) ERC20("GJZ Vesting Credit", "GJZ") {
        if (power == address(0)) revert InvalidAddress();
        controller = power;
    }

    function mint(address account, uint256 amount) external {
        if (msg.sender != controller) revert ControllerOnly();
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external {
        if (msg.sender != controller) revert ControllerOnly();
        _burn(account, amount);
    }

    function _update(address from, address to, uint256 amount) internal override {
        if (from != address(0) && to != address(0)) revert NonTransferable();
        super._update(from, to, amount);
    }
}
