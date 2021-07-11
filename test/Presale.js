const { BigNumber } = require("@ethersproject/bignumber");
const hre = require("hardhat");

const { expect }  = require('chai')

//const accounts = await ethers.getSigners();


const expectedSettings = {
  'ROUND1_LENGTH':     533,
  'BASE_FEE':          18, // 1.8%
  'TOKEN_FEE':         18, // 1.8%
  'ETH_CREATION_FEE':  500000000000000000, // 0.5BNB
  'ETH_FEE_ADDRESS':   null, // Should be msg.sender
  'testTokenIERC20': null, // Should be msg.sender
  'ROUND1_LENGTH':     533, // 553 blocks = 2 hours
  'MAX_PRESALE_LENGTH': 93046 // 2 weeks
};

describe("Presale Contract", function() {
  it ("Presale Settings match expected settings", async function() {
    const accounts = await hre.ethers.getSigners();
    const presaleSettings = await hre.ethers.getContractFactory('PresaleSettings');
    const presaleSettingsContract = await presaleSettings.deploy();
    const presaleSettingsAddress = await presaleSettingsContract.address;

    expect(await presaleSettingsContract.getRound1Length()).to.equal(expectedSettings.ROUND1_LENGTH);
    expect(await presaleSettingsContract.getMaxPresaleLength()).to.equal(expectedSettings.MAX_PRESALE_LENGTH);
    expect(await presaleSettingsContract.getBaseFee()).to.equal(expectedSettings.BASE_FEE);

    expect(await presaleSettingsContract.getTokenFee()).to.equal(expectedSettings.TOKEN_FEE);
    //expect(await presaleSettingsContract.getEthCreationFee()).to.equal(expectedSettings.ETH_CREATION_FEE);
    expect(await presaleSettingsContract.getEthAddress()).to.equal(accounts[0].address);
    expect(await presaleSettingsContract.getTokenAddress()).to.equal(accounts[0].address);

    await presaleSettingsContract.setFeeAddresses(accounts[1].address, accounts[2].address)

    expect(await presaleSettingsContract.getEthAddress()).to.equal(accounts[1].address);
    expect(await presaleSettingsContract.getTokenAddress()).to.equal(accounts[2].address);
  });

  it ("Testing presale factory blacklisting users", async function() {
    const accounts = await hre.ethers.getSigners();
    const presaleFactory = await ethers.getContractFactory('PresaleFactory');
    const presaleFactoryContract = await presaleFactory.deploy();
    const presaleFactoryAddress = presaleFactoryContract.address;

    expect(await presaleFactoryContract.isBlacklisted(accounts[1].address)).to.equal(false);
    presaleFactoryContract.blacklistUser(accounts[1].address, true);
    expect(await presaleFactoryContract.isBlacklisted(accounts[1].address)).to.equal(true);
    presaleFactoryContract.blacklistUser(accounts[1].address, false);
    expect(await presaleFactoryContract.isBlacklisted(accounts[1].address)).to.equal(false);
  });

  it ("Testing presale generator whitelisting", async function() {
    const accounts = await ethers.getSigners();

    const WBNB = await hre.ethers.getContractFactory("WBNB");
    const wbnbContract = await WBNB.deploy();
    const wbnbAddress = wbnbContract.address;
    
    const psFactory = await hre.ethers.getContractFactory("PancakeFactory");
    const psFactoryContract = await psFactory.deploy(accounts[0].address);
    const psFactoryAddress = psFactoryContract.address;
    
    const psRouter = await hre.ethers.getContractFactory("PancakeRouter");
    const psRouterContract = await psRouter.deploy(psFactoryAddress, wbnbAddress);
    const psRouterAddress = psRouterContract.address;

    const uniswapV2Locker = await hre.ethers.getContractFactory('UniswapV2Locker');
    const uniswapV2LockerContract = await uniswapV2Locker.deploy(psRouterAddress);
    const uniswapV2LockerAddress = uniswapV2LockerContract.address;

    const presaleSettings = await ethers.getContractFactory('PresaleSettings');
    const presaleSettingsContract = await presaleSettings.deploy();
    const presaleSettingsAddress = presaleSettingsContract.address;

    const presaleFactory = await ethers.getContractFactory('PresaleFactory');
    const presaleFactoryContract = await presaleFactory.deploy();
    const presaleFactoryAddress = presaleFactoryContract.address;

    const devAddress = accounts[2].address;
    const userAddress = accounts[3].address;

    const testTokenGenerator = await ethers.getContractFactory('TestToken', devAddress);
    const testTokenGeneratorContract = await testTokenGenerator.deploy();
    const testTokenGeneratorAddress = testTokenGeneratorContract.address;

    const presaleGenerator = await ethers.getContractFactory('PresaleGenerator01');
    const presaleGeneratorContract = await presaleGenerator.deploy(presaleFactoryAddress, presaleSettingsAddress, userAddress);
    const presaleGeneratorAddress = presaleGeneratorContract.address;

    const now = await hre.network.provider.send('eth_blockNumber');

    const presaleParams = [
      100,                 // amount
      1,                   // token price
      10,                  // max spend per buyer 
      10000,               // hardcap
      5000,                // softcap
      40,                  // liquidity percent
      1,                   // listing rate
      now,                 // start block 
      now + 533,           // end block 533 = 2 hours
      60 * 60 * 24 * 365   // lock period 1 year
    ];

    //presaleParams = hre.utils.solidityPack(['uint256', 'uint256', 'uint256', 'uint256', 'uint256', 
    //                        'uint256', 'uint256', 'uint256', 'uint256', 'uint256'],
    //                      presaleParams);

    await presaleGeneratorContract.createPresale(devAddress, testTokenGeneratorAddress, wbnbAddress, "0x000000000000000000000000000000000000dead", presaleParams);
  });
});

