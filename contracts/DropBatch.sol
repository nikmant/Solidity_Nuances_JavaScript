// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DropBatch is Ownable {
    struct StructDrop {
        IERC20 token;
        uint amount;
    }
    mapping(address => bool) public wasAlreadyDrop;
    StructDrop[] public dropableTokens;

    // =================================
    // Constructor
    // =================================

    constructor() {
    }

    // =================================
    // Main Functions
    // =================================

    // Add token to drop
    function addTokenToDrop(address _token, uint _amountTotal, uint _amountForOne) external onlyOwner {
        require(_token != address(0), "Address token is zero!");        
        require(_amountTotal > 0, "Amount total is zero!");
        require(_amountForOne > 0, "Amount for one is zero!");
        require(_amountTotal >= _amountForOne, "Amount total less than amount for one!");
        // Add token to drop
        dropableTokens.push(StructDrop(IERC20(_token), _amountForOne));
        // Approve tokens to send        
        IERC20(_token).approve(address(this), _amountTotal);
        // Transfer tokens to contract
        IERC20(_token).transferFrom(msg.sender, address(this), _amountTotal);
    }

    // Get drop all tokens for user
    function getDrop() external {
        // Check that user not get drop before
        require(!wasAlreadyDrop[msg.sender], "You already get drop.");
        // Set that user get drop
        wasAlreadyDrop[msg.sender] = true;
        // Transfer tokens to user for each token
        for(uint i = 0; i < dropableTokens.length; i++) {
            // Check that contract have enough tokens
            if (dropableTokens[i].token.balanceOf(address(this)) >= dropableTokens[i].amount) {
                // Transfer tokens to user
                dropableTokens[i].token.transfer(msg.sender, dropableTokens[i].amount);
                // Emit event
                emit GetAirDrop(msg.sender, dropableTokens[i].amount);
            }
        }
    }

    // Withdraw all tokens from contract to the Owner
    function balanceWithdraw() external onlyOwner {
        // Transfer tokens back for each token
        for(uint i = 0; i < dropableTokens.length; i++) {
            // Calc balance of the token in this contract
            uint value = dropableTokens[i].token.balanceOf(address(this));
            // If balance more than zero
            if (value>0) {
                // Transfer tokens to Owner
                dropableTokens[i].token.transfer(owner(), value);
                // Emit event
                emit GetAirDrop(owner(), value);
            }
        }
    }


    // =================================
    // Additional Functions
    // =================================    
    
    // Change drop-amount for one token
    function changeAmountDrop(address _token, uint _newAmountDrop) external onlyOwner {
        // Run through all tokens
        for(uint i = 0; i < dropableTokens.length; i++) {
            // If token found
            if (address(dropableTokens[i].token) == _token) {
                // Change amount
                dropableTokens[i].amount = _newAmountDrop;
                break;
            }
        }
    }

    // Delete token from drop
    function deleteTokenFromDrop(address _deletedToken) public onlyOwner {
        // Run through all tokens
        for(uint i = 0; i < dropableTokens.length; i++) {
            // If token found
            if (address(dropableTokens[i].token) == _deletedToken) {
                // Delete this token from array
                dropableTokens[i] = dropableTokens[dropableTokens.length - 1];
                dropableTokens.pop();
                break;
            }
        }        
    }

    // Clear info about drop for one user
    function clearInfoAboutDrop(address _addr) public onlyOwner {
        wasAlreadyDrop[_addr] = false;
    }

    
    // =================================
    // Internal Functions
    // =================================

    function renounceOwnership() public pure override {
        revert("Not success!");
    }

    event GetAirDrop(address dropper, uint amount);

}