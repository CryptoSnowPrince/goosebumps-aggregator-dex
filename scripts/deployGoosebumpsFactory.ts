import { ethers } from "hardhat";

async function main() {
  const accountList = await ethers.getSigners();
  const _feeToSetter = accountList[0].address;

  const GoosebumpsFactory = await ethers.getContractFactory("GoosebumpsFactory");
  console.log("_feeToSetter: ", _feeToSetter);
  const goosebumpsFactory = await GoosebumpsFactory.deploy(_feeToSetter);

  await goosebumpsFactory.deployed();

  console.log("GoosebumpsFactory deployed to:", goosebumpsFactory.address);

  const INIT_CODE_PAIR_HASH = await goosebumpsFactory.INIT_CODE_PAIR_HASH();
  
  console.log("GoosebumpsFactory INIT_CODE_PAIR_HASH:", INIT_CODE_PAIR_HASH);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
