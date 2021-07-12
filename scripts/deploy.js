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

  const arenaManagerGenerator = await ethers.getContractFactory('ArenaManager');
  const arenaManagerGeneratorContract = await arenaManagerGenerator.deploy(psRouterAddress, wbnbAddress);
  const arenaManagerGeneratorAddress = arenaManagerGeneratorContract.address;
  console.log(`ArenaManager deployed to: ${arenaManagerGeneratorAddress}`);

  //const contendorGenerator = await ethers.getContractFactory('Contendor');

  //const redGeneratorContract = await contendorGenerator.deploy(arenaManagerGeneratorAddress, "VersusRed", "VR");
  //const blueGeneratorContract = await contendorGenerator.deploy(arenaManagerGeneratorAddress, "VersusBlue", "VB");

  //const redAddress = redGeneratorContract.address;
  //const blueAddress = blueGeneratorContract.address;

  //console.log(`Red deployed to: ${redAddress}`);
  //console.log(`Blue deployed to: ${blueAddress}`);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    })
