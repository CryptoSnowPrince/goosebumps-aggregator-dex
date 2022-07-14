import { ethers } from "hardhat";

async function main() {
  // bsc testnet
  const _baseFactory = "0x1c064B00B88Eff150DBC93b0712382e9D7b4e881";
  const _routerPairs = "0xE66982213A41B7A57e23582c645E7FB76d09156D";
  const _WETH = "0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd";
  const _aggregator = "0x98A4EC1bF304514f13C508e62b5af190C93Fdae5";

  console.log("_baseFactory: ", _baseFactory);
  console.log("_routerPairs: ", _routerPairs);
  console.log("_WETH: ", _WETH);
  console.log("_aggregator: ", _aggregator);
  const GoosebumpsRouter = await ethers.getContractFactory("GoosebumpsRouter");
  const goosebumpsRouter = await GoosebumpsRouter.deploy(_baseFactory, _routerPairs, _WETH, _aggregator);

  await goosebumpsRouter.deployed();

  console.log("GoosebumpsRouter deployed to:", goosebumpsRouter.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
