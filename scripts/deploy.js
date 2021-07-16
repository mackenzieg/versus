const { BigNumber } = require("@ethersproject/bignumber");
//const { ethers } = require("hardhat");
const hre = require("hardhat");

async function main() {
  await hre.run('compile');
  
  const accounts = await ethers.getSigners();

  const WBNB = await hre.ethers.getContractFactory("WBNB");
  const wbnbContract = await WBNB.deploy();
  const wbnbAddress = wbnbContract.address;
  console.log("WBNB deployed to:", wbnbAddress);

  const BUSD = await hre.ethers.getContractFactory("BUSD");
  const busdContract = await BUSD.deploy();
  const busdAddress = busdContract.address;
  console.log("BUSD deployed to:", busdAddress);
  
  const psFactory = await hre.ethers.getContractFactory("PancakeFactory");
  const psFactoryContract = await psFactory.deploy(accounts[0].address);
  const psFactoryAddress = psFactoryContract.address;
  console.log('FACTORY HASH: ' + await psFactoryContract.INIT_CODE_PAIR_HASH());
  console.log("Factory deployed to:", psFactoryAddress);
  
  const psRouter = await hre.ethers.getContractFactory("PancakeRouter");
  const psRouterContract = await psRouter.deploy(psFactoryAddress, wbnbAddress);
  const psRouterAddress = psRouterContract.address;
  console.log("Router deployed to:", psRouterAddress);

  const uniswapV2Locker = await hre.ethers.getContractFactory('UniswapV2Locker');
  const uniswapV2LockerContract = await uniswapV2Locker.deploy(psRouterAddress);
  const uniswapV2LockerAddress = uniswapV2LockerContract.address;
  console.log(`Locker deployed to: ${uniswapV2LockerAddress}`);

  const arenaManager = await ethers.getContractFactory('ArenaManager');
  const arenaManagerContract = await arenaManager.deploy(psRouterAddress, wbnbAddress, busdAddress);
  const arenaManagerAddress = arenaManagerContract.address;
  console.log(`ArenaManager deployed to: ${arenaManagerAddress}`);

  const iterableMapping = await ethers.getContractFactory('IterableMapping');
  const iterableMappingContract = await iterableMapping.deploy();
  const iterableMappingAddress = iterableMappingContract.address;

  console.log("Deploying dividend trackers");
  const dividendTrackerGenerator = await ethers.getContractFactory('ContesterDividendTracker', {
        libraries: {
          IterableMapping: iterableMappingAddress
        }
      });

  const redDividendTrackerContract = await dividendTrackerGenerator.deploy("RedDividendTracker", "RDT");
  const blueDividendTrackerContract = await dividendTrackerGenerator.deploy("BlueDividendTracker", "BDT");

  const redDividendTrackerAddress = redDividendTrackerContract.address;
  const blueDividendTrackerAddress = blueDividendTrackerContract.address;

  console.log(`Red Dividend Tracker deployed to: ${redDividendTrackerAddress}`);
  console.log(`Blue Dividend Tracker deployed to: ${blueDividendTrackerAddress}`);

  const contender = await ethers.getContractFactory('Contender');

  const redContract = await contender.deploy(arenaManagerAddress, redDividendTrackerAddress, psRouterAddress, wbnbAddress, busdAddress, "VersusRed", "VR");
  const blueContract = await contender.deploy(arenaManagerAddress, blueDividendTrackerAddress, psRouterAddress, wbnbAddress, busdAddress, "VersusBlue", "VB");

  const redAddress = redContract.address;
  const blueAddress = blueContract.address;

  console.log(`Red deployed to: ${redAddress}`);
  console.log(`Blue deployed to: ${blueAddress}`);


  console.log("Linking ArenaManager to contenders");
  arenaManagerContract.changeContenders(redAddress, blueAddress);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    })
