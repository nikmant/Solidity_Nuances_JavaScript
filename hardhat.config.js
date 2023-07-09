require("@nomicfoundation/hardhat-toolbox");

// The next line is part of the sample project, you don't need it in your
// project. It imports a Hardhat task definition, that can be used for
// testing the frontend.
require("./tasks/faucet");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  // Add versions "0.8.17","0.8.18" of Solidity compiler
  solidity: {
    compilers: [
      {
        version: "0.8.17",
      },
      {
        version: "0.8.18",
      },
    ],
  },
};
