
import { BigNumberish, constants, Signer, Wallet } from 'ethers';
import { artifacts, ethers, waffle } from 'hardhat';
import { expect } from 'chai';
import { abi as DropBatch } from '../artifacts/contracts/DropBatch.sol/DropBatch.json';
import { abi as TokenERC20 } from '../artifacts/contracts/TokenERC20.sol/TokenERC20.json';

describe('Test DropBatch contract', () => {
  let wallets: Wallet[];
  let tokensERC20: TokenERC20[];
  let contractDropBatch: DropBatch;

  before(async () => {
    wallets = await ethers.getSigners();
    tokensERC20 = [];
    // Create TokenERC20 contract
    for (let i = 0; i < 10; i++) {
      var TokenERC20 = await ethers.getContractFactory('TokenERC20');
      var nname = 'TX'+i;
      var newToken = await TokenERC20.deploy(nname, nname, 10_000_000_000 + i+1);
      await newToken.deployed();
      tokensERC20.push( newToken );
      console.log('TokenERC20['+i+'] deployed to:', tokensERC20[i].address);
    }
    var a = await tokensERC20[0].balanceOf(wallets[0].address);
    console.log('token0 balance:', a);
    var a = await tokensERC20[1].balanceOf(wallets[0].address);
    console.log('token1 balance:', a);    
  });

  // create dropbatch contract
  beforeEach(async () => { 
    const DropBatch = await ethers.getContractFactory('DropBatch');
    contractDropBatch = await DropBatch.deploy();
    await contractDropBatch.deployed();
    console.log('DropBatch deployed to:', contractDropBatch.address);
  });

  // test add token to drop
  it('Add token to drop', async () => {
    // await contractDropBatch.connect(wallets[0]).addTokenToDrop(tokensERC20[0].address, 1, 1);
    // await contractDropBatch.addTokenToDrop(tokensERC20[0].address, 50_000_000, 50);
    // contractDropBatch.addTokenToDrop(tokensERC20[1].address, 30_000_000, 30);
    // const dropableTokens = await contractDropBatch.dropableTokens();
    // const res = dropableTokens[0];
    // expect(res.tokenAddress).to.equal(tokensERC20[0].address);
  });

  it('Add token to drop', async () => {
  //   await contractDropBatch.addTokenToDrop(tokensERC20[0].address, 50_000_000, 50);
  //   await contractDropBatch.addTokenToDrop(tokensERC20[1].address, 30_000_000, 30);
  //   const dropableTokens = await contractDropBatch.dropableTokens();
  //   const res = dropableTokens[0];
  //   expect(res.tokenAddress).to.equal(tokensERC20[0].address);
  });

  // 

})