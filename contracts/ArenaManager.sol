/**
 *Submitted for verification at BscScan.com on 2021-05-20
*/

// File: @uniswap\lib\contracts\libraries\TransferHelper.sol

pragma solidity 0.6.12;

import "./libraries/TransferHelper.sol";
import "./libraries/IERC20.sol";
import "./libraries/SafeMath.sol";
import "./libraries/Privileged.sol";
import "./libraries/IPancake.sol";
import "./libraries/UQ112x112.sol";
import "./libraries/IContender.sol";
import "./BUSD.sol";
import "./IArenaManager.sol";
import "hardhat/console.sol";

abstract contract ERC20Interface {
    function balanceOf(address whom) virtual public returns (uint);
    function transfer(address recipient, uint256 amount) virtual external returns (bool);
    function approve(address spender, uint256 amount) virtual external returns (bool);
}

contract ArenaManager is Privileged, IArenaManager {
    using UQ112x112 for uint224;
    struct ArenaManagerStatus {
        uint256 nextCompetitionEndTime;
        uint256 nextGiveawayEndTime; 

        uint256 lastCompetitionEndTime;

        bool arenaManagerEnabled;

        uint32 previousState;

        bool giveawayEnabled;
        uint256 COMPETITION_TIME;
        uint256 GIVEAWAY_TIME;

        bool redTeamAdvantage;
        bool blueTeamAdvantage;
        uint256 redTeamAdvantageTime;
        uint256 blueTeamAdvantageTime;
    }

    address private _red;
    address private _blue;
    
    address private _wbnb;
    address private _busd;
    
    address payable private router;
    
    mapping (address => uint256) public balances;

    IPancakeRouter02 _pr;

    string private _name = 'ArenaManager';
    string private _symbol = 'ARENAM';

    ArenaManagerStatus private STATUS;

    // use by default 300,000 gas to process auto-claiming dividends
    uint256 public gasForProcessing = 300000;

    uint256 private minBalanceRequired = 2 ether;

    constructor (address payable psRouter, address payable wbnb, address payable busd) public {
      router = psRouter;
      _pr = IPancakeRouter02(psRouter);
      _wbnb = wbnb;
      _busd = busd;

      // Timestamp really far out
      uint256 YEAR3000 = 32520475068;
      
      STATUS.nextCompetitionEndTime = YEAR3000;
      STATUS.nextGiveawayEndTime = YEAR3000; 

      STATUS.arenaManagerEnabled = false;

      STATUS.giveawayEnabled = false;
      STATUS.COMPETITION_TIME = 3 days;
      STATUS.GIVEAWAY_TIME = 1 hours;
      
      STATUS.redTeamAdvantage = false;
      STATUS.blueTeamAdvantage = false;
    }

    function changeAMEnable(bool enabled) external onlyPriviledged() {
        STATUS.arenaManagerEnabled = enabled;
    }

    function changeGiveawayEnable(bool enabled) external onlyPriviledged() {
        STATUS.giveawayEnabled = enabled;
    }

    function setMinBalanceRequired(uint256 bal) external onlyPriviledged() {
        minBalanceRequired = bal;
    }

    function changeContenders(address red, address blue) external onlyPriviledged() {
        _red = red;
        _blue = blue;
        updatePriviledged(red, blue);
    }

    function getRedContender() external view returns (address) {
        return _red;
    }

    function getBlueContender() external view returns (address) {
        return _blue;
    }

    function setRedTeamAdvanatage(uint256 time) external onlyPriviledged() {
      STATUS.redTeamAdvantage = true;
      STATUS.redTeamAdvantageTime = block.timestamp + time;
    }

    function setBlueTeamAdvanatage(uint256 time) external onlyPriviledged() {
      STATUS.blueTeamAdvantage = true;
      STATUS.blueTeamAdvantageTime = block.timestamp + time;
    }

    function updateGasForProcessing(uint256 newValue) public onlyPriviledged() {
        gasForProcessing = newValue;
    }

    function setCurrentCompetitionEndTime(uint256 competitionTime) external onlyPriviledged() {
      STATUS.nextCompetitionEndTime = competitionTime;
    }

    function setCurrentGiveawayEndTime(uint256 giveawayTime) external onlyPriviledged() {
      STATUS.nextGiveawayEndTime = giveawayTime;
      STATUS.lastCompetitionEndTime = giveawayTime;
    }

    function setCompeitionTimingLimits(uint256 competitionTime, uint256 giveawayTime) external onlyPriviledged() {
      STATUS.COMPETITION_TIME = competitionTime;
      STATUS.GIVEAWAY_TIME = giveawayTime;
    }

    function getWinner() private returns (address) { //returns address of winner
      IPancakePair redPair = IPancakePair(IPancakeFactory(_pr.factory()).getPair(_red, _wbnb));
      IPancakePair bluePair = IPancakePair(IPancakeFactory(_pr.factory()).getPair(_blue, _wbnb));


      (uint112 redA, uint112 redB, ) = redPair.getReserves();


      uint112 redToken;
      uint112 redWBNB;
      uint112 blueToken;
      uint112 blueWBNB;

      if (redPair.token0() == _red) {
          redToken = redA;
          redWBNB = redB;
      } else {
          redToken = redB;
          redWBNB = redA;
      }

      (uint112 blueA, uint112 blueB, ) = bluePair.getReserves();

      if (bluePair.token0() == _blue) {
          blueToken = blueA;
          blueWBNB = blueB;
      } else {
          blueToken = blueB;
          blueWBNB = blueA;
      }

      uint224 redPrice = UQ112x112.encode(redWBNB).uqdiv(redToken);
      uint224 bluePrice = UQ112x112.encode(blueWBNB).uqdiv(blueToken);

      console.log('RED PRICE', redPrice);
      console.log('BLUE PRICE', bluePrice);

      if (redPrice > bluePrice) {
        return _red;
      } else {
        return _blue;
      }
    }

    function currentState() public returns (uint32) {

      if (!STATUS.giveawayEnabled) {
        // Giveaway disabled
        return 0;
      } else if (block.timestamp < STATUS.nextCompetitionEndTime) {
        // Currently in competition mode 
        return 1;
      } else {
        // Currently in giveaway mode
        return 2;
      }
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }
    
    fallback () external payable {}

    receive () external payable {}
    
    function queryERC20Balance(address _tokenAddress, address _addressToQuery) private returns (uint256) {
        return ERC20Interface(_tokenAddress).balanceOf(_addressToQuery);
    }
    
    function withdrawBNB() external onlyPriviledged() payable {
        _msgSender().transfer(address(this).balance);
    }
    
    function withdrawToken(address tokenA) external onlyPriviledged() payable {
        
        updateBalances();
        
        uint256 tAmount = balances[tokenA];
        
        ERC20Interface(tokenA).transfer(owner(), tAmount);
    }
    
    function updateBalances() private {
        balances[_red] = queryERC20Balance(_red, address(this));
        balances[_blue] = queryERC20Balance(_blue, address(this));
    }
    
    function updateBal() external {
        balances[_red] = queryERC20Balance(_red, address(this));
        balances[_blue] = queryERC20Balance(_blue, address(this));
    }

    function updateState() private {
        uint32 state = currentState();
        uint256 currTime = block.timestamp;
        uint256 nextCompetitionEndTime = STATUS.nextCompetitionEndTime;

        STATUS.previousState = state;

        console.log('Inside update state');
        console.log(state);

        if (state == 1 && currTime < nextCompetitionEndTime) {
            console.log('Here1');
            if (STATUS.redTeamAdvantage && currTime >= STATUS.redTeamAdvantageTime) {
                STATUS.redTeamAdvantage = false;
            }

            if (STATUS.blueTeamAdvantage && currTime >= STATUS.blueTeamAdvantageTime) {
                STATUS.blueTeamAdvantage = false;
            }

        } else if (state == 1 && currTime >= nextCompetitionEndTime) {
            console.log('Here2');
            // Store last competition time so period between competition is always GIVEAWAY_TIME
            STATUS.lastCompetitionEndTime = nextCompetitionEndTime;
            
            // Update end of giveaway time
            // Edge case here, use currTime instead of lastCompetitionEndTime as if the last transfer happens after giveaway
            // time it would skip giveaway time
            STATUS.nextGiveawayEndTime = currTime + STATUS.GIVEAWAY_TIME;
        } else if (state == 2 && currTime >= STATUS.nextGiveawayEndTime) {
            console.log(currTime);
            console.log(STATUS.nextGiveawayEndTime);
            console.log('Here3');
            // Update end of next competition time
            STATUS.nextCompetitionEndTime = STATUS.lastCompetitionEndTime + STATUS.GIVEAWAY_TIME;
        }
    }

    function executeBasedOnState() private {
        uint32 state = currentState();

        
        console.log('Current State:');
        console.log(state);

        // Giveaway state
        if (state == 2) {

            console.log(STATUS.previousState);

            IERC20 iBUSD = IERC20(_busd); 
            IContender iRED = IContender(_red);
            IContender iBLUE = IContender(_blue);

            uint256 busdBal = iBUSD.balanceOf(address(this));

            address redDivAddr = iRED.getDividendTrackerContract();
            address blueDivAddr = iBLUE.getDividendTrackerContract();

            address winner = getWinner();
            if (winner == _red) {
                // Only transfer BUSD on first giveaway state
                if (STATUS.previousState != 2 && busdBal > 0)
                    console.log('SHOULD HAVE PAID OUT');
                    iBUSD.transfer(redDivAddr, busdBal);
                iRED.deanAnnounceWinner(gasForProcessing);
            } else {
                // Only transfer BUSD on first giveaway state
                if (STATUS.previousState != 2 && busdBal > 0)
                    console.log('SHOULD HAVE PAID OUT');
                    iBUSD.transfer(blueDivAddr, busdBal);
                    iBLUE.deanAnnounceWinner(gasForProcessing);
            }
        } else if (state != 2 && STATUS.previousState == 2) {
            IContender iRED = IContender(_red);
            IContender iBLUE = IContender(_blue);
            iRED.deanRetractExtraBUSD();
            iBLUE.deanRetractExtraBUSD();
        }
    }

    // TODO to reduce repeat code consider just passing if its a buy or sell as a bool into a single function
    function contenderBuy(uint256 amount) override public {
        require((_msgSender() == _red || _msgSender() == _blue || _msgSender() == owner()), "Can only be called by Red or Blue token contract");

        if (!STATUS.arenaManagerEnabled) {
            return;
        }

        executeBasedOnState();
        
        updateState();


        bool isRed = _msgSender() == _red;

        // Need to figure out what the logic should really be
        if (isRed) {
            // Red team buy so sell blue
            if (!STATUS.blueTeamAdvantage)
                sell(_blue, amount);
        } else {
            // Blue team buy so sell red
            if (!STATUS.redTeamAdvantage)
                sell(_red, amount);
        }
    }

    function contenderSell(uint256 amount) override public {
        require((_msgSender() == _red || _msgSender() == _blue || _msgSender() == owner()), "Can only be called by Red or Blue token contract");


        if (!STATUS.arenaManagerEnabled) {
            return;
        }

        executeBasedOnState();

        updateState();

        if (address(this).balance >= minBalanceRequired) {
            return;
        }

        bool isRed = _msgSender() == _red;

        // Need to figure out what the logic should really be
        if (isRed) {
            if (!STATUS.redTeamAdvantage)
                buy(_blue, amount);
        } else {
            if (!STATUS.blueTeamAdvantage)
                buy(_red, amount);
        }
    }

    function tokenToBNB(address tokenA, uint256 amount) private  returns (uint256){

      address[] memory path = new address[](2);

      path[0] = tokenA;
      path[1] = _wbnb;

      uint[] memory amounts = _pr.getAmountsOut(amount, path);

      return amounts[1];
    }
    
    function buy (address tokenA, uint256 amount) private {
        address[] memory path = new address[](2);
        
        uint256 bnbAmount = address(this).balance;
        bnbAmount = SafeMath.div(bnbAmount, 100);

        uint256 bnbPrice = tokenToBNB(tokenA, amount);

        if (bnbPrice <= bnbAmount) {
          bnbAmount = bnbPrice;
        }
        
        path[0] = _wbnb;
        path[1] = tokenA;
        
        _pr.swapExactETHForTokensSupportingFeeOnTransferTokens.value(bnbAmount)(
        0,
        path,
        address(this),
        block.timestamp);
        
        updateBalances();
        
    }
    
    function sell (address tokenA, uint256 amount) private {
        updateBalances();
        
        address[] memory path = new address[](2);
        
        uint tokenAmount = balances[tokenA];

        tokenAmount = SafeMath.div(tokenAmount, 100);

        if (amount <= tokenAmount) {
          tokenAmount = amount;
        }
        
        
        path[0] = tokenA;
        path[1] = _wbnb;
        
        ERC20Interface(tokenA).approve(router, tokenAmount);
        
        _pr.swapExactTokensForETHSupportingFeeOnTransferTokens(
        tokenAmount,
        0,
        path,
        address(this),
        block.timestamp);
        
        updateBalances();
    }
}
