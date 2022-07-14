import { ethers } from "hardhat";

async function main() {
  const _aggregator = "0x98A4EC1bF304514f13C508e62b5af190C93Fdae5";

  console.log("_aggregator: ", _aggregator);
  const GoosebumpsRouterPairs = await ethers.getContractFactory("GoosebumpsRouterPairs");
  const goosebumpsRouterPairs = await GoosebumpsRouterPairs.deploy(_aggregator);

  await goosebumpsRouterPairs.deployed();

  console.log("GoosebumpsRouterPairs deployed to:", goosebumpsRouterPairs.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
