const hre = require("hardhat");
async function main() 
{
    const signer = (await hre.ethers.getSigners())[0];
    const OZ_Test = (await ethers.getContractFactory('OZ_Test', signer));
    const OZ_Test_InBlockchain = (await OZ_Test.deploy(3));

  console.log("Signer Addr: ", signer.address);

  await OZ_Test_InBlockchain.deployed();
  console.log("Contract Addr: ", OZ_Test_InBlockchain.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    })