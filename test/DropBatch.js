const { expect } = require("chai");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

describe("Testing DropBatch", function () {
    async function deployTokenFixture() {

      const [owner, addr1, addr2] = await ethers.getSigners();

      const Token = await ethers.getContractFactory("TokenERC20");
      const hardhatToken = await Token.deploy('AAA', 'AAA', 1_000_000_000);  
      await hardhatToken.deployed();
      console.log("    TokenERC20 address: ", hardhatToken.address);

      const DropBatch = await ethers.getContractFactory("DropBatch");
      const hardhatDropBatch = await DropBatch.deploy();  
      await hardhatDropBatch.deployed();
      console.log("    DropBatch address: ", hardhatDropBatch.address);

      return { hardhatToken, hardhatDropBatch, owner, addr1, addr2 };
    }

  describe("Deployment", function () {
    it("Address != 0", async function () {
      const { hardhatDropBatch } = await loadFixture(deployTokenFixture);
      expect(hardhatDropBatch.address).to.not.equal(0);
    });
  });

  describe("Work with DropBatch", function () {
    it("Add token", async function () {
      const { hardhatToken, hardhatDropBatch, owner } = await loadFixture(deployTokenFixture);
      hardhatDropBatch.addTokenToDrop('AAA', 1_000_000, 10);
    });
  });

  describe("Work with DropBatch", function () {
    it("Add token", async function () {
      const { hardhatToken, hardhatDropBatch, owner, addr1 } = await loadFixture(deployTokenFixture);
      hardhatDropBatch.TestApprove(hardhatToken.address, addr1.address, 12357);
      console.log( await hardhatToken.allowance(owner.address, addr1.address) );
      
      // approve
      await hardhatToken.connect(owner).approve(addr1.address, 12357);
      await hardhatToken.connect(owner).approve(hardhatDropBatch.address, 12357);
      console.log("allowance from ",owner.address,"to",addr1.address,"=", await hardhatToken.allowance(owner.address, addr1.address) );

      await hardhatToken.connect(addr1).transferFrom(owner.address, addr1.address, 123);

      console.log( await hardhatToken.balanceOf(owner.address) );
      console.log( await hardhatToken.balanceOf(addr1.address) );
      console.log( await hardhatToken.balanceOf(hardhatToken.address) );

      // console.log( await hardhatToken.allowance(owner.address, 0) );
      // expect(hardhatDropBatch.address).to.not.equal(0);
    });
  });
  

});