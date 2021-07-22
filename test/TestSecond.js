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

        this.BUSD = await hre.ethers.getContractFactory("BUSD", this.psDeployer);

        this.psFactory = await hre.ethers.getContractFactory("PancakeFactory", this.psDeployer);
        this.psRouter = await hre.ethers.getContractFactory("PancakeRouter", this.psDeployer);
        this.uniswapV2Locker = await hre.ethers.getContractFactory('UniswapV2Locker', this.psDeployer);
        this.arenaManager = await ethers.getContractFactory('ArenaManager', this.arenaDeployer);
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

        this.redDividendTrackerContract = await this.redDividendTrackerGenerator.deploy("RedDividendTracker", "RDT", this.busdAddress);
        this.blueDividendTrackerContract = await this.blueDividendTrackerGenerator.deploy("BlueDividendTracker", "BDT", this.busdAddress);

        this.redDividendTrackerAddress = this.redDividendTrackerContract.address;
        this.blueDividendTrackerAddress = this.blueDividendTrackerContract.address;

        this.redContract = await this.redContender.deploy(this.arenaManagerAddress, this.redDividendTrackerAddress, this.psRouterAddress, this.wbnbAddress, this.busdAddress, "VersusRed", "VR");
        this.blueContract = await this.blueContender.deploy(this.arenaManagerAddress, this.blueDividendTrackerAddress, this.psRouterAddress, this.wbnbAddress, this.busdAddress, "VersusBlue", "VB");

        this.redAddress = this.redContract.address;
        this.blueAddress = this.blueContract.address;

        this.redDividendTrackerContract.setContender(this.redAddress);
        this.blueDividendTrackerContract.setContender(this.blueAddress);

        await this.redContract.setDividendTracker(this.redDividendTrackerAddress);
        await this.blueContract.setDividendTracker(this.blueDividendTrackerAddress);

        this.arenaManagerContract.changeContenders(this.redAddress, this.blueAddress);

        await this.busdContract.connect(this.psDeployer).mint('1000000000000000000000000'); //mint $1m

        let deployTime = new Date().getTime();

        //add 1m BUSD and 100 BNB to BUSD/BNB liquidity 
        await this.busdContract.connect(this.psDeployer).approve(this.psRouterAddress, '1000000000000000000000000');
        await this.psRouterContract.connect(this.psDeployer).addLiquidityETH(this.busdAddress, '1000000000000000000000000', 0, 0, this.psDeployer.address, deployTime + 1000, {value: '100000000000000000000'});

        await this.redContract.connect(this.redDeployer).addExcluded(this.arenaManagerAddress);
        await this.blueContract.connect(this.blueDeployer).addExcluded(this.arenaManagerAddress);
        await this.redContract.connect(this.redDeployer).addExcluded(this.redAddress);
        await this.blueContract.connect(this.blueDeployer).addExcluded(this.blueAddress);
    });

    // Checks linking between dividend, mm and conteder
    it("Check network mappings", async function () {
        // Contender is linked to Dividend contract
        console.log(await this.redContract.getDividendTrackerContract());
        console.log("asdasd");
        expect(await this.redContract.getDividendTrackerContract()).to.equal(this.redDividendTrackerContract.address);
        //expect(await this.blueContract.getDividendTrackerContract()).to.equal(this.blueDividendTrackerAddress);
    });

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

    //it("Get factory hash", async function () {
    //    const hash = this.psDeployer.connect(this.psFactory).INIT_CODE_PAIR_HASH
    //    console.log('Factory hash: ' + hash);
    //});

    it("Check able to add initial liquidity", async function () {
        const amountTokenLP = 1000000 * 10**9;
        const amountBNBLP = BigInt(10000000000000000000); // 10 BNB

        const now = new Date().getTime();

        await this.redContract.connect(this.redDeployer).approve(this.psRouterAddress, amountTokenLP);
        await this.psRouterContract.connect(this.redDeployer).addLiquidityETH(this.redAddress, amountTokenLP, 0, 0, this.redDeployer.address, now + 300, {value: amountBNBLP});

    });

    it("Check if buying with tax off works", async function () {

      //Add Liquidity

      const amountTokenLP = 1000000 * 10**9;
      const amountBNBLP = BigInt(10000000000000000000); // 10 BNB

      const now = new Date().getTime();

      await this.redContract.connect(this.redDeployer).approve(this.psRouterAddress, amountTokenLP);
      await this.psRouterContract.connect(this.redDeployer).addLiquidityETH(this.redAddress, amountTokenLP, 0, 0, this.redDeployer.address, now + 300, {value: amountBNBLP});

      //Buy 1BNB worth on 10 accounts

      const toBuy = BigInt(1000000000000000000); // 1 BNB

      const path = [this.wbnbAddress, this.redAddress];

      for (const account of this.signers.slice(10)) {

        expect(await this.redContract.balanceOf(account.address) == 0);

        const now = new Date().getTime();

        await this.psRouterContract.connect(account).swapExactETHForTokensSupportingFeeOnTransferTokens(0, path, account.address, now + 300, {value: toBuy});

        expect(await this.redContract.balanceOf(account.address) > 0);
      }

    });

    it("Check if buying with tax on works", async function () {

      //Add Liquidity

      const amountTokenLP = 1000000 * 10**9;
      const amountBNBLP = BigInt(10000000000000000000); // 10 BNB

      const now = new Date().getTime();

      await this.redContract.connect(this.redDeployer).approve(this.psRouterAddress, amountTokenLP);
      await this.psRouterContract.connect(this.redDeployer).addLiquidityETH(this.redAddress, amountTokenLP, 0, 0, this.redDeployer.address, now + 300, {value: amountBNBLP});

      //Enable tax

      await this.redContract.connect(this.redDeployer).setTax(true);

      //Buy 1BNB worth on 10 accounts

      const toBuy = BigInt(1000000000000000000); // 1 BNB

      const path = [this.wbnbAddress, this.redAddress];

      for (const account of this.signers.slice(10)) {

        expect(await this.redContract.balanceOf(account.address) == 0);

        const now = new Date().getTime();

        await this.psRouterContract.connect(account).swapExactETHForTokensSupportingFeeOnTransferTokens(0, path, account.address, now + 300, {value: toBuy});

        expect(await this.redContract.balanceOf(account.address) > 0);
      }

    });

    it("Check if correct total tax is taken", async function () {

      //Add Liquidity

      const amountTokenLP = 1000000 * 10**9;
      const amountBNBLP = BigInt(10000000000000000000); // 10 BNB

      const now = new Date().getTime();

      await this.redContract.connect(this.redDeployer).approve(this.psRouterAddress, amountTokenLP);
      await this.psRouterContract.connect(this.redDeployer).addLiquidityETH(this.redAddress, amountTokenLP, 0, 0, this.redDeployer.address, now + 300, {value: amountBNBLP});

      //Enable tax

      await this.redContract.connect(this.redDeployer).setTax(true);

      //Buy 1BNB worth on 10 accounts

      const toBuy = BigInt(1000000000000000000); // 1 BNB

      const path = [this.wbnbAddress, this.redAddress];

      let tokensBought = BigInt(0);

      for (const account of this.signers.slice(10)) {

        expect(await this.redContract.balanceOf(account.address) == 0);

        const now = new Date().getTime();

        await this.psRouterContract.connect(account).swapExactETHForTokensSupportingFeeOnTransferTokens(0, path, account.address, now + 300, {value: toBuy});

        expect(await this.redContract.balanceOf(account.address) > 0);

        tokensBought += BigInt(await this.redContract.balanceOf(account.address));
      }

      let contractTokens = BigInt(await this.redContract.balanceOf(this.redAddress));

      let taxAmount = await this.redContract.getTaxes();

      expect(((tokensBought+contractTokens) / contractTokens) == (100 / taxAmount));

    });

    it("Check if buying/selling works with AM + Tax", async function () {

      //Add Liquidity

      const amountTokenLP = BigInt("100000000000000000");
      const amountBNBLP = BigInt(10000000000000000000); // 10 BNB

      const now = new Date().getTime();

      await this.redContract.connect(this.redDeployer).approve(this.psRouterAddress, amountTokenLP);
      await this.psRouterContract.connect(this.redDeployer).addLiquidityETH(this.redAddress, amountTokenLP, 0, 0, this.redDeployer.address, now + 300, {value: amountBNBLP});

      await this.blueContract.connect(this.blueDeployer).approve(this.psRouterAddress, amountTokenLP);
      await this.psRouterContract.connect(this.blueDeployer).addLiquidityETH(this.blueAddress, amountTokenLP, 0, 0, this.blueDeployer.address, now + 300, {value: amountBNBLP});

      //Send tokens to AM

      await this.redContract.connect(this.redDeployer).transfer(this.arenaManagerAddress, amountTokenLP);
      await this.blueContract.connect(this.blueDeployer).transfer(this.arenaManagerAddress, amountTokenLP);

      //Enable AM

      await this.arenaManagerContract.connect(this.arenaDeployer).changeAMEnable(true);

      //Enable Giveaway

      await this.arenaManagerContract.connect(this.arenaDeployer).changeGiveawayEnable(true);

      //Enable tax

      await this.redContract.connect(this.redDeployer).setTax(true);

      //Enable swap and liq

      await this.redContract.connect(this.redDeployer).setSwapAndLiqEnabled(true);

      //Buy 1BNB worth on 10 accounts

      const toBuy = BigInt(1000000000000000000); // 1 BNB

      let path = [this.wbnbAddress, this.redAddress];

      for (const account of this.signers.slice(5)) {

        expect(await this.redContract.balanceOf(account.address) == 0);

        const now = new Date().getTime();

        await this.psRouterContract.connect(account).swapExactETHForTokensSupportingFeeOnTransferTokens(0, path, account.address, now + 300, {value: toBuy});

        expect(await this.redContract.balanceOf(account.address) > 0);

      }

      path = [this.redAddress, this.wbnbAddress];

      for (const account of this.signers.slice(5)) {

        const toSell = await this.redContract.balanceOf(account.address);

        const now = new Date().getTime();

        await this.redContract.connect(account).approve(this.psRouterAddress, toSell);
        await this.psRouterContract.connect(account).swapExactTokensForETHSupportingFeeOnTransferTokens(toSell, 0, path, account.address, now + 300);

      }

      path = [this.wbnbAddress, this.blueAddress];

      for (const account of this.signers.slice(5)) {

        expect(await this.blueContract.balanceOf(account.address) == 0);

        const now = new Date().getTime();

        await this.psRouterContract.connect(account).swapExactETHForTokensSupportingFeeOnTransferTokens(0, path, account.address, now + 300, {value: toBuy});

        expect(await this.blueContract.balanceOf(account.address) > 0);

      }

      for (const account of this.signers.slice(5)) {
        console.log(account.address + ' div token bal: ' + await this.blueDividendTrackerContract.balanceOf(account.address))
      }

      console.log('FORCING GIVEAWAY TO START');

      const compEnd = new Date().getTime();

      await this.arenaManagerContract.connect(this.arenaDeployer).setCurrentCompetitionEndTime(compEnd);
      await hre.ethers.provider.send('evm_setNextBlockTimestamp', [compEnd]);  //Change network timestamp to match

      path = [this.blueAddress, this.wbnbAddress];

      for (const account of this.signers.slice(5)) {

        console.log('RED DIV BUSD: ' + await this.busdContract.balanceOf(this.redDividendTrackerAddress));
        console.log('BLUE DIV BUSD: ' + await this.busdContract.balanceOf(this.blueDividendTrackerAddress));

        const toSell = await this.blueContract.balanceOf(account.address);

        const now = new Date().getTime();

        await this.blueContract.connect(account).approve(this.psRouterAddress, toSell);
        await this.psRouterContract.connect(account).swapExactTokensForETHSupportingFeeOnTransferTokens(toSell, 0, path, account.address, now + 300);

      }

      for (const account of this.signers.slice(5)) {

        console.log(account.address + ' busd bal: ' + await this.busdContract.balanceOf(account.address));

      }

      console.log('RED DIV BUSD: ' + await this.busdContract.balanceOf(this.redDividendTrackerAddress));
      console.log('BLUE DIV BUSD: ' + await this.busdContract.balanceOf(this.blueDividendTrackerAddress));
      

      expect(await this.busdContract.balanceOf(this.arenaManagerAddress) > 0); //Check if AM got BUSD from fees
      expect(await hre.ethers.provider.getBalance(this.arenaManagerAddress) > 0); //Check if AM got BNB from fees

      expect(await this.blueContract.balanceOf(this.arenaManagerAddress) < amountTokenLP); //Check if AM was selling/buying opposite tokens (below initial since starts with no BNB)

      console.log('FORCING GIVEAWAY TO END');

      const giveawayEnd = new Date().getTime();

      await this.arenaManagerContract.connect(this.arenaDeployer).setCurrentGiveawayEndTime(giveawayEnd);
      await hre.ethers.provider.send('evm_setNextBlockTimestamp', [giveawayEnd]);  //Change network timestamp to match

      path = [this.wbnbAddress, this.blueAddress];

      for (const account of this.signers.slice(5)) {
        const now = new Date().getTime();

        await this.psRouterContract.connect(account).swapExactETHForTokensSupportingFeeOnTransferTokens(0, path, account.address, now + 300, {value: toBuy});
      }

      path = [this.blueAddress, this.wbnbAddress];

      for (const account of this.signers.slice(5)) {

        console.log('RED DIV BUSD: ' + await this.busdContract.balanceOf(this.redDividendTrackerAddress));
        console.log('BLUE DIV BUSD: ' + await this.busdContract.balanceOf(this.blueDividendTrackerAddress));

        const toSell = await this.blueContract.balanceOf(account.address);

        const now = new Date().getTime();

        await this.blueContract.connect(account).approve(this.psRouterAddress, toSell);
        await this.psRouterContract.connect(account).swapExactTokensForETHSupportingFeeOnTransferTokens(toSell, 0, path, account.address, now + 300);

      }

      console.log('RED DIV BUSD: ' + await this.busdContract.balanceOf(this.redDividendTrackerAddress));
      console.log('BLUE DIV BUSD: ' + await this.busdContract.balanceOf(this.blueDividendTrackerAddress));
      

      expect(await this.busdContract.balanceOf(this.redDividendTrackerAddress) == 0);
      expect(await this.busdContract.balanceOf(this.blueDividendTrackerAddress) == 0);

    });
  //await expectRevert.unspecified(scamToken.connect(secondComer).airdropTokens(secondComer.address));
// https://dev.to/steadylearner/how-to-test-a-bep20-token-with-hardhat-and-not-get-scamed-5bjj
});

