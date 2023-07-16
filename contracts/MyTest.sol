// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "hardhat/console.sol";

contract MyTest 
{
    constructor(uint256 _unlockedTime) 
    {
        require(block.timestamp < _unlockedTime);
    }

    function Say18() 
    public
    pure
    returns (uint) 
    {
        return 18;
    }
}