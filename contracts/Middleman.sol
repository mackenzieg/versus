/**
 *Submitted for verification at BscScan.com on 2021-05-20
*/

// File: @uniswap\lib\contracts\libraries\TransferHelper.sol

pragma solidity >=0.6.0;

import "./libraries/TransferHelper.sol";
import "./libraries/IERC20.sol";
import "./libraries/SafeMath.sol";
import "./libraries/Ownable.sol";

// File: contracts\interfaces\IPancakeRouter01.sol

pragma solidity >=0.6.2;

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

pragma solidity >=0.6.2;

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

pragma solidity >=0.5.0;

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

// File: contracts\libraries\SafeMath.sol

pragma solidity >=0.6.6;

// File: contracts\interfaces\IPancakePair.sol

pragma solidity >=0.5.0;

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

pragma solidity >=0.5.0;

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}

// File: contracts\PancakeRouter.sol

pragma solidity =0.6.12;

abstract contract ERC20Interface {
    function balanceOf(address whom) virtual public returns (uint);
    function transfer(address recipient, uint256 amount) virtual external returns (bool);
    function approve(address spender, uint256 amount) virtual external returns (bool);
}

contract ArenaManager is Ownable {
    address private _white = address(0);
    address private _black = address(0);
    
    address private _wbnb;
    
    address payable private router;
    
    mapping (address => uint256) public balances;

    IPancakeRouter02 _pr;

    string private _name = 'ArenaManager';
    string private _symbol = 'ARENAM';

    constructor (address payable psRouter, address payable wbnb) public {
      router = psRouter;
      _pr = IPancakeRouter02(psRouter);
      _wbnb = wbnb;
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
    
    function changeWhite(address newW) external onlyOwner() {
        _white = newW;
    }
    
    function changeBlack(address newB) external onlyOwner() {
        _black = newB;
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
        balances[_white] = queryERC20Balance(_white, address(this));
        balances[_black] = queryERC20Balance(_black, address(this));
    }
    
    function updateBal() external {
        balances[_white] = queryERC20Balance(_white, address(this));
        balances[_black] = queryERC20Balance(_black, address(this));
    }
    
    function buyWhite() external {
        require((_msgSender() == _white || _msgSender() == _black || _msgSender() == owner()), "Can only be called by W or B token contract");
        buy(_white);
    }
    
    function sellWhite() external {
        require((_msgSender() == _white || _msgSender() == _black || _msgSender() == owner()), "Can only be called by W or B token contract");
        sell(_white);
    }
    
    function buyBlack() external {
        require((_msgSender() == _white || _msgSender() == _black || _msgSender() == owner()), "Can only be called by W or B token contract");
        buy(_black);
    }
    
    function sellBlack() external {
        require((_msgSender() == _white || _msgSender() == _black || _msgSender() == owner()), "Can only be called by W or B token contract");
        sell(_black);
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
