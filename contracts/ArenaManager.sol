/**
 *Submitted for verification at BscScan.com on 2021-05-20
*/

// File: @uniswap\lib\contracts\libraries\TransferHelper.sol

pragma solidity 0.6.12;

import "./libraries/TransferHelper.sol";
import "./libraries/IERC20.sol";
import "./libraries/SafeMath.sol";
import "./libraries/Ownable.sol";
import "./libraries/IPancake.sol";
import "./BUSD.sol";
import "./IArenaManager.sol";

abstract contract ERC20Interface {
    function balanceOf(address whom) virtual public returns (uint);
    function transfer(address recipient, uint256 amount) virtual external returns (bool);
    function approve(address spender, uint256 amount) virtual external returns (bool);
}

contract ArenaManager is Ownable, IArenaManager {
    struct ArenaManagerStatus {
      uint256 nextCompetitionEndTime;
      uint256 nextGiveawayEndTime; 

      uint256 lastCompetitionEndTime;

      bool arenaManagerEnabled;
      
      bool giveawayEnabled;
      uint256 COMPETITION_TIME;
      uint256 GIVEAWAY_TIME;
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
    }

    function setCurrentCompetitionEndTime(uint256 competitionTime) external onlyOwner() {
      STATUS.nextCompetitionEndTime = competitionTime;
    }

    function setCurrentGiveawayEndTime(uint256 giveawayTime) external onlyOwner() {
      STATUS.nextGiveawayEndTime = giveawayTime;
    }

    function setCompeitionTimingLimits(uint256 competitionTime, uint256 giveawayTime) external onlyOwner() {
      STATUS.COMPETITION_TIME = competitionTime;
      STATUS.GIVEAWAY_TIME = giveawayTime;
    }

    function currentState() public returns (uint32) {
      if (!STATUS.giveawayEnabled) {
        // Giveaway disabled
        return 0;
      } else if (block.timestamp < STATUS.nextGiveawayEndTime) {
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
    
    function changeRed(address red) external onlyOwner() {
        _red = red;
    }
    
    function changeBlue(address blue) external onlyOwner() {
        _blue = blue;
    }

    function changeContenders(address red, address blue) external onlyOwner() {
        _red = red;
        _blue = red;
    }
    
    
    function withdrawBNB() external onlyOwner payable {
        _msgSender().transfer(address(this).balance);
    }
    
    function withdrawToken(address tokenA) external onlyOwner payable {
        
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
        if (state == 1 && currTime >= STATUS.nextCompetitionEndTime) {
          // Store last competition time so period between competition is always GIVEAWAY_TIME
          STATUS.lastCompetitionEndTime = STATUS.nextCompetitionEndTime;
          
          // Update end of giveaway time
          // Edge case here, use currTime instead of lastCompetitionEndTime as if the last transfer happens after giveaway
          // time it would skip giveaway time
          STATUS.nextGiveawayEndTime = currTime + STATUS.GIVEAWAY_TIME;
        } else if (state == 2 && currTime >= STATUS.nextGiveawayEndTime) {
          // Update end of next competition time
          STATUS.nextCompetitionEndTime = STATUS.lastCompetitionEndTime + STATUS.GIVEAWAY_TIME;
        }
    }

    function executeBasedOnState() private {
        uint32 state = currentState();

        if (state == 2) {
          // Check who is winning and send out giveaway here 
        }
    }

    // TODO to reduce repeat code consider just passing if its a buy or sell as a bool into a single function
    function contenderBuy(uint256 amount) override public {
        require((_msgSender() == _red || _msgSender() == _blue || _msgSender() == owner()), "Can only be called by Red or Blue token contract");

        updateState();

        executeBasedOnState();


        bool isRed = true;
        if (_msgSender() == _blue){
          isRed = false;
        }

        // Need to figure out what the logic should really be
        if (isRed) {
          sell(_blue);
        } else {
          sell(_red);
        }
    }

    function contenderSell(uint256 amount) override public {
        require((_msgSender() == _red || _msgSender() == _blue || _msgSender() == owner()), "Can only be called by Red or Blue token contract");

        bool isRed = true;
        if (_msgSender() == _blue){
          isRed = false;
        }

        // Need to figure out what the logic should really be
        if (isRed) {
          buy(_blue);
        } else {
          buy(_red);
        }
    }
    
    function buy (address tokenA) private {
        address[] memory path = new address[](2);
        
        uint256 bnbAmount = address(this).balance;
        bnbAmount = SafeMath.div(bnbAmount, 100);
        
        path[0] = _wbnb;
        path[1] = tokenA;
        
        _pr.swapExactETHForTokensSupportingFeeOnTransferTokens.value(bnbAmount)(
        0,
        path,
        address(this),
        block.timestamp);
        
        updateBalances();
        
    }
    
    function sell (address tokenA) private {
        updateBalances();
        
        address[] memory path = new address[](2);
        
        uint tokenAmount = balances[tokenA];
        tokenAmount = SafeMath.div(tokenAmount, 100);
        
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
