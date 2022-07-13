import { ethers } from "hardhat";

async function main() {
  const FeeAggregator = await ethers.getContractFactory("FeeAggregator");
  const feeAggregator = await FeeAggregator.deploy();

  await feeAggregator.deployed();

  console.log("FeeAggregator deployed to:", feeAggregator.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
