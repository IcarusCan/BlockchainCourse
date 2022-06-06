// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // We get the contract to deploy
  let gold
  let staking
  let reserve

  //deploy Gold
  const Gold = await ethers.getContractFactory("Gold")
  gold = await Gold.deploy()
  await gold.deployed()
  console.log("Gold deployed to:", gold.address)

  //deploy Staking
  const Staking = await ethers.getContractFactory("Staking")
  staking = await Staking.deploy(gold.address)
  await staking.deployed()
  console.log("Staking deployed to:", staking.address);
  
  //deploy StakingReserve
  const Reserve = await ethers.getContractFactory("StakingReserve")
  reserve = await Reserve.deploy(gold.address, staking.address)
  await reserve.deployed()
  console.log("Reserve deployed to:", reserve.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
