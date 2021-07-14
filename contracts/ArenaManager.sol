/**
 *Submitted for verification at BscScan.com on 2021-05-20
*/

// File: @uniswap\lib\contracts\libraries\TransferHelper.sol

pragma solidity 0.6.12;

import "./libraries/TransferHelper.sol";
import "./libraries/IERC20.sol";
import "./libraries/SafeMath.sol";
import "./libraries/Ownable.sol";
import "./IArenaManager.sol";

// File: contracts\interfaces\IPancakeRouter01.sol

//pragma solidity >=0.6.2;

interface IPancakeRouter01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

// File: contracts\interfaces\IPancakeRouter02.sol

//pragma solidity >=0.7.6;

interface IPancakeRouter02 is IPancakeRouter01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

// File: contracts\interfaces\IPancakeFactory.sol

//pragma solidity >=0.5.0;

interface IPancakeFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;

    function INIT_CODE_PAIR_HASH() external view returns (bytes32);
}

// File: contracts\interfaces\IPancakePair.sol

//pragma solidity >=0.5.0;

interface IPancakePair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}

// File: contracts\interfaces\IWETH.sol

//pragma solidity >=0.5.0;

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}

// File: contracts\PancakeRouter.sol

//pragma solidity >=0.6.12;

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
    
    address payable private router;
    
    mapping (address => uint256) public balances;

    IPancakeRouter02 _pr;

    string private _name = 'ArenaManager';
    string private _symbol = 'ARENAM';

    ArenaManagerStatus private STATUS;

    constructor (address payable psRouter, address payable wbnb) public {
      router = psRouter;
      _pr = IPancakeRouter02(psRouter);
      _wbnb = wbnb;


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

    function contenderBuy(uint256 amount) override public {
        require((_msgSender() == _red || _msgSender() == _blue || _msgSender() == owner()), "Can only be called by Red or Blue token contract");


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
