// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract HGG is IERC20 {
    string public constant name = "HGG Share";
    string public constant symbol = "HGG";
    uint8 public constant decimals = 18;
    uint256 public constant INDEX_SCALE = 1e27;
    address public immutable controller;
    uint256 public index = INDEX_SCALE;
    uint256 public totalShares;
    mapping(address => uint256) public sharesOf;
    mapping(address => mapping(address => uint256)) public override allowance;

    error ControllerOnly();
    error InvalidAmount();
    error InvalidAddress();
    error InsufficientBalance();
    error InsufficientAllowance();
    error IndexExhausted();

    event Rebased(uint256 previousIndex, uint256 newIndex);

    constructor(address power) {
        if (power == address(0)) revert InvalidAddress();
        controller = power;
    }

    modifier onlyController() {
        if (msg.sender != controller) revert ControllerOnly();
        _;
    }

    function totalSupply() public view override returns (uint256) {
        return Math.mulDiv(totalShares, index, INDEX_SCALE);
    }

    function balanceOf(address account) public view override returns (uint256) {
        return Math.mulDiv(sharesOf[account], index, INDEX_SCALE);
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        if (spender == address(0)) revert InvalidAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        uint256 available = allowance[from][msg.sender];
        if (available != type(uint256).max) {
            if (available < amount) revert InsufficientAllowance();
            allowance[from][msg.sender] = available - amount;
            emit Approval(from, msg.sender, available - amount);
        }
        _transfer(from, to, amount);
        return true;
    }

    function mint(address account, uint256 amount) external onlyController returns (uint256 actual) {
        if (account == address(0)) revert InvalidAddress();
        uint256 shares = Math.mulDiv(amount, INDEX_SCALE, index);
        if (shares == 0) revert InvalidAmount();
        totalShares += shares;
        sharesOf[account] += shares;
        actual = Math.mulDiv(shares, index, INDEX_SCALE);
        emit Transfer(address(0), account, actual);
    }

    function burn(address account, uint256 amount) external onlyController {
        uint256 shares = _sharesForDebit(account, amount);
        sharesOf[account] -= shares;
        totalShares -= shares;
        emit Transfer(account, address(0), amount);
    }

    function rebase(uint256 oldPrice, uint256 newPrice) external onlyController {
        if (oldPrice == 0 || newPrice < oldPrice) revert InvalidAmount();
        uint256 next = Math.mulDiv(index, oldPrice, newPrice);
        if (next == 0) revert IndexExhausted();
        emit Rebased(index, next);
        index = next;
    }

    function rebaseByFactor(uint256 factor) external onlyController {
        if (factor == 0 || factor > 1e18) revert InvalidAmount();
        uint256 next = Math.mulDiv(index, factor, 1e18);
        if (next == 0 || (totalShares != 0 && Math.mulDiv(totalShares, next, INDEX_SCALE) == 0)) {
            revert IndexExhausted();
        }
        emit Rebased(index, next);
        index = next;
    }

    function _sharesForDebit(address account, uint256 amount) private view returns (uint256) {
        uint256 balance = balanceOf(account);
        if (amount > balance) revert InsufficientBalance();
        if (amount == 0) return 0;
        if (amount == balance) return sharesOf[account];
        return Math.mulDiv(amount, INDEX_SCALE, index, Math.Rounding.Ceil);
    }

    function _transfer(address from, address to, uint256 amount) private {
        if (from == address(0) || to == address(0)) revert InvalidAddress();
        uint256 shares = _sharesForDebit(from, amount);
        sharesOf[from] -= shares;
        sharesOf[to] += shares;
        emit Transfer(from, to, amount);
    }
}
