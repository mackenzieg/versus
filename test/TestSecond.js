const { BigNumber } = require("@ethersproject/bignumber");
const hre = require("hardhat");

const { expect }  = require('chai')

describe("Versus Tests Second", function() {
    before(async function () {
        this.signers = await ethers.getSigners();
        this.redDeployer = this.signers[1];
        this.blueDeployer = this.signers[2];
        this.arenaDeployer = this.signers[3];
        this.psDeployer = this.signers[4];

        this.WBNB = await hre.ethers.getContractFactory("WBNB");

        this.BUSD = await hre.ethers.getContractFactory("BUSD");

        this.psFactory = await hre.ethers.getContractFactory("PancakeFactory", this.psDeployer);
        this.psRouter = await hre.ethers.getContractFactory("PancakeRouter", this.psDeployer);
        this.uniswapV2Locker = await hre.ethers.getContractFactory('UniswapV2Locker', this.psDeployer);
        this.arenaManager = await ethers.getContractFactory('ArenaManager', this.arenaManager);
        this.redIterableMapping = await ethers.getContractFactory('IterableMapping', this.redDeployer);
        this.blueIterableMapping = await ethers.getContractFactory('IterableMapping', this.blueDeployer);

        this.redContender = await ethers.getContractFactory('Contender', this.redDeployer);
        this.blueContender = await ethers.getContractFactory('Contender', this.blueDeployer);
    });

    beforeEach(async function() {
        this.wbnbContract = await this.WBNB.deploy();
        this.wbnbAddress = this.wbnbContract.address;

        this.busdContract = await this.BUSD.deploy();
        this.busdAddress = this.busdContract.address;

        this.psFactoryContract = await this.psFactory.deploy(this.psDeployer.address);
        this.psFactoryAddress = this.psFactoryContract.address;

        this.psRouterContract = await this.psRouter.deploy(this.psFactoryAddress, this.wbnbAddress);
        this.psRouterAddress = this.psRouterContract.address;

        this.uniswapV2LockerContract = await this.uniswapV2Locker.deploy(this.psRouterAddress);
        this.uniswapV2LockerAddress = this.uniswapV2LockerContract.address;

        this.arenaManagerContract = await this.arenaManager.deploy(this.psRouterAddress, this.wbnbAddress, this.busdAddress);
        this.arenaManagerAddress = this.arenaManagerContract.address;

        this.redIterableMappingContract = await this.redIterableMapping.deploy();
        this.blueIterableMappingContract = await this.blueIterableMapping.deploy();
        this.redIterableMappingAddress = this.redIterableMappingContract.address;
        this.blueIterableMappingAddress = this.blueIterableMappingContract.address;

        this.redDividendTrackerGenerator = await ethers.getContractFactory('ContesterDividendTracker', {
            libraries: {
              IterableMapping: this.redIterableMappingAddress
            }
          }, this.blueDeployer);

        this.blueDividendTrackerGenerator = await ethers.getContractFactory('ContesterDividendTracker', {
            libraries: {
              IterableMapping: this.blueIterableMappingAddress
            }
          }, this.redDeployer);

        this.redDividendTrackerContract = await this.redDividendTrackerGenerator.deploy("RedDividendTracker", "RDT");
        this.blueDividendTrackerContract = await this.blueDividendTrackerGenerator.deploy("BlueDividendTracker", "BDT");

        this.redDividendTrackerAddress = this.redDividendTrackerContract.address;
        this.blueDividendTrackerAddress = this.blueDividendTrackerContract.address;

        this.redContract = await this.redContender.deploy(this.arenaManagerAddress, this.redDividendTrackerAddress, this.psRouterAddress, this.wbnbAddress, this.busdAddress, "VersusRed", "VR");
        this.blueContract = await this.blueContender.deploy(this.arenaManagerAddress, this.blueDividendTrackerAddress, this.psRouterAddress, this.wbnbAddress, this.busdAddress, "VersusBlue", "VB");

        this.redAddress = this.redContract.address;
        this.blueAddress = this.blueContract.address;

        this.redDividendTrackerContract.setContender(this.redAddress);
        this.blueDividendTrackerContract.setContender(this.blueAddress);

        this.redContract.setDividendTracker(this.redDividendTrackerAddress);
        this.blueContract.setDividendTracker(this.blueDividendTrackerAddress);

        this.arenaManagerContract.changeContenders(this.redAddress, this.blueAddress);
    });

    // Checks linking between dividend, mm and conteder
    //it("Check network mappings", async function () {
    //    // Contender is linked to Dividend contract
    //    console.log(await this.redContract.getDividendTrackerContract());
    //    console.log("asdasd");
    //    expect(await this.redContract.getDividendTrackerContract()).to.equal(this.redDividendTrackerContract.address);
    //    //expect(await this.blueContract.getDividendTrackerContract()).to.equal(this.blueDividendTrackerAddress);
    //});

    // Check number of tokens held
    it("Check taxes can be changed", async function () {
        expect(await this.redContract.getTaxes()).to.equal(10);
        this.redContract.changeTax(20);
        expect(await this.redContract.getTaxes()).to.equal(20);
        this.redContract.changeTax(10);
        expect(await this.redContract.getTaxes()).to.equal(10);

        const taxShares = await this.redContract.getTaxShares();

        expect(await taxShares[0]).to.equal(50);
        expect(await taxShares[1]).to.equal(20);
        expect(await taxShares[2]).to.equal(20);
        expect(await taxShares[3]).to.equal(10);

        await this.redContract.changeTaxShares(1, 2, 3, 4);

        const taxSharesChanged = await this.redContract.getTaxShares();

        expect(await taxSharesChanged[0]).to.equal(1);
        expect(await taxSharesChanged[1]).to.equal(2);
        expect(await taxSharesChanged[2]).to.equal(3);
        expect(await taxSharesChanged[3]).to.equal(4);
    });

    it("Check able to add liquidity", async function () {
        const amountTokenLP = 1000000 * 10**9;

        prov = ethers.getDefaultProvider();

        const amountBNBLP = await (prov.getBalance(this.redDeployer.address) / 1000);
        
        this.psRouterContract.addLiquidityETH(this.redAddress, amount)

        this.redContract.addLiquidity(amountTokenLP, amountBNBLP);
        //this.psRouterContract.swapExactETHForTokensSupportingFeeOnTransferTokens()
    });
});

