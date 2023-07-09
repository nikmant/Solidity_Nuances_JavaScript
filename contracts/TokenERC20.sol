// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TokenERC20 is ERC20 {
    constructor(string memory name_, string memory symbol_, uint amount_) ERC20(name_, symbol_) {
        _mint(msg.sender, amount_ * 10 ** decimals());
    }
}