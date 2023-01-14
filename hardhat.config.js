/** @type import('hardhat/config').HardhatUserConfig */
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("hardhat-deploy")
require("dotenv").config();
module.exports = {
  solidity: "0.8.17",
};
