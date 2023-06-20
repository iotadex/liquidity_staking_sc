// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  const rewardToken = "0x3Cf63EB3afE4b4717e78eAe99d632321fc5Ce519";
  //  const StakeERC20 = await hre.ethers.getContractFactory("StakeERC20");
  //  const erc20 = await StakeERC20.deploy(52, 2, 52, 0, 999999999999999999n, rewardToken, "0x406153d92579841835E820Ed2631384CA6910dE0");
  //  await erc20.deployed();
  //  console.log(`deployed StakeERC20 to ${erc20.address}`);
  //  return;
  /*
          uint8 maxWeeks,
          uint256 maxScale,
          uint8 lockWeeks,
          uint256 beginTime,
          uint256 endTime,
          address _rewardToken,
          address tokenA,
          address tokenB,
          uint24 _fee,
          address nft,
          int24 tickMin
  */
  const t0 = "0x3Cf63EB3afE4b4717e78eAe99d632321fc5Ce519";
  const t1 = "0x8202AC9838d3F199D3BaD2336e05e52507146659";
  const fee = 10000;
  const NFT = "0xdE6dE59e33f61eB6B9F4f183323Cf505375906D6";
  const tcikMax = 887200;
  const StakeNFT721 = await hre.ethers.getContractFactory("StakeNFT721");
  const nft = await StakeNFT721.deploy(52, 2, 52, 0, 999999999999999999n, rewardToken, t0, t1, fee, NFT, tcikMax);
  await nft.deployed();
  console.log(`deployed StakeNFT721 to ${nft.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
