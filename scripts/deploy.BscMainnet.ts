import { ethers } from "hardhat";

async function main() {
  // const currentTimestampInSeconds = Math.round(Date.now() / 1000);
  // const ONE_YEAR_IN_SECS = 365 * 24 * 60 * 60;
  // const unlockTime = currentTimestampInSeconds + ONE_YEAR_IN_SECS;

  // const lockedAmount = ethers.utils.parseEther("1");

  // const Lock = await ethers.getContractFactory("Lock");
  // const lock = await Lock.deploy(unlockTime, { value: lockedAmount });

  // await lock.deployed();

  // console.log("Lock with 1 ETH deployed to:", lock.address);

  // BSC Mainnet

  const accountList = await ethers.getSigners();
  // deployer = 0x6E56D9a73C2b5D099DD18C32F4541402fF92A634
  const deployer = accountList[0];
  const _WETH = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c";

  console.log("deployer address:", deployer.address);

  // FeeAggregator
  const FeeAggregator = await ethers.getContractFactory("FeeAggregator");
  const feeAggregator = await FeeAggregator.deploy();

  await feeAggregator.deployed();

  console.log("FeeAggregator deployed to:", feeAggregator.address);

  // GoosebumpsFactory
  const GoosebumpsFactory = await ethers.getContractFactory("GoosebumpsFactory");
  const _feeToSetter = "0x64966A4871C900B9EF0236a93b6FbD345C79c8c0";
  console.log("_feeToSetter: ", _feeToSetter);
  const goosebumpsFactory = await GoosebumpsFactory.deploy(_feeToSetter);

  await goosebumpsFactory.deployed();

  console.log("GoosebumpsFactory deployed to:", goosebumpsFactory.address);

  const INIT_CODE_PAIR_HASH = await goosebumpsFactory.INIT_CODE_PAIR_HASH();
  
  console.log("GoosebumpsFactory INIT_CODE_PAIR_HASH:", INIT_CODE_PAIR_HASH);

  // GoosebumpsRouterPairs
  const _aggregator = feeAggregator.address;
  console.log("_aggregator: ", feeAggregator.address);
  const GoosebumpsRouterPairs = await ethers.getContractFactory("GoosebumpsRouterPairs");
  const goosebumpsRouterPairs = await GoosebumpsRouterPairs.deploy(_aggregator);

  await goosebumpsRouterPairs.deployed();

  console.log("GoosebumpsRouterPairs deployed to:", goosebumpsRouterPairs.address);

  // GoosebumpsRouter
  const _baseFactory = goosebumpsFactory.address;
  const _routerPairs = goosebumpsRouterPairs.address;

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
