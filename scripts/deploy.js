// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  const rewardToken = "0x8CB067473a564F2e72cBcd21d2e2d01CfcB4D222";
  const StakeERC20 = await hre.ethers.getContractFactory("StakeERC20");
  const erc20 = await StakeERC20.deploy(52, 2, rewardToken, "0x189eFf58f4E76F740adD2E235f5155b974C02C17");
  await erc20.deployed();
  console.log(`deployed StakeERC20 to ${erc20.address}`);
  return;

  const StakeNFT721 = await hre.ethers.getContractFactory("StakeNFT721");
  const nft = await StakeNFT721.deploy(52, 2, "", "", rewardToken, "0x9146142b4A4bDfc3496FEc84F160081a12715e0C");
  await nft.deployed();
  console.log(`deployed StakeNFT721 to ${nft.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
