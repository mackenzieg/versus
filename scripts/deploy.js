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

  const redGenerator = await ethers.getContractFactory('VersusRed');
  const redGeneratorContract = await redGenerator.deploy(arenaManagerGeneratorAddress);
  const redGeneratorAddress = redGeneratorContract.address;
  console.log(`Red deployed to: ${redGeneratorAddress}`);

  const blueGenerator = await ethers.getContractFactory('VersusBlue');
  const blueGeneratorContract = await blueGenerator.deploy(arenaManagerGeneratorAddress);
  const blueGeneratorAddress = blueGeneratorContract.address;
  console.log(`Blue deployed to: ${blueGeneratorAddress}`);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    })
