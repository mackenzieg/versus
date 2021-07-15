pragma solidity 0.6.12;

import "./libraries/TransferHelper.sol";
import "./libraries/IERC20.sol";
import "./libraries/SafeMath.sol";
import "./libraries/Ownable.sol";
import "./libraries/Address.sol";
import "./IArenaManager.sol";
import "./ArenaManager.sol";

interface IDividendPayingToken {
  function withdrawableDividendOf(address _owner) external view returns(uint256);
  function withdrawnDividendOf(address _owner) external view returns(uint256);
  function accumulativeDividendOf(address _owner) external view returns(uint256);

  function dividendOf(address _owner) external view returns(uint256);
  function distributeDividends() external payable;
  function withdrawDividend() external;
  event DividendsDistributed(
    address indexed from,
    uint256 weiAmount
  );
  event DividendWithdrawn(
    address indexed to,
    uint256 weiAmount
  );
}


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

contract Contender is Context, IERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;

    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;
   
    uint256 private constant _total = 10**9 * 10**9; //1B Total Supply

    uint256 public _taxAmount = 0;

    //@dev 5% prize pool, 2% auto-lp, 2% marketing, 1% arena manager. weird math to fit all fees into one swap.

    uint256 private _prizePoolShare = 5555; 
    //uint256 private _marketingShare = 2222;
    uint256 private _lpShare = 1111;
    uint256 private _amShare = 1111;

    uint256 private _lpShareDiv = 10;

    uint256 public _minTokensForSwap = _total.mul(5).div(1000); //500k Tokens
    bool public _taxOn = false;
    
    address payable private _arenaManager;
    IDividendPayingToken private _dividendTracker;
    
    ArenaManager AM;
    
    address private _pair = address(0);
    address private _router = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address private _wbnb = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address private _busd = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;

    IPancakeRouter02 _routerInterface = IPancakeRouter02(_router);

    address[] private _wbnbPath = [address(this), _wbnb];
    address[] private _busdPath = [_wbnb, _busd];

    mapping (address => bool) _excluded;
 
    address payable private _marketingWallet = 0x1366b918Fb5b78c6cf574f32B304255B3A3C8060;

    string private _name;
    string private _symbol;
    uint8 private _decimals = 9;

    constructor (address payable arenaManager, address payable dividendTracker, string memory name, string memory symbol) public {
        _arenaManager = arenaManager;
        AM = ArenaManager(arenaManager);
        _dividendTracker = IDividendPayingToken(dividendTracker);

        _name = name;
        _symbol = symbol;

        _balances[_msgSender()] = _total;
        emit Transfer(address(0), _msgSender(), _total);

    }

    function addExcluded(address addr) external onlyOwner() {
        _excluded[addr] = true;
    }

    function removeExcluded(address addr) external onlyOwner() {
        _excluded[addr] = false;
    }

    function changeTaxShares(uint256 pp, uint256 marketing, uint256 lp, uint256 am) external onlyOwner() {
        _prizePoolShareDiv = pp; 
        _marketingShareDiv = marketing;
        _lpShareDiv = lp;
        _amShareDiv = am;
    }
    
    function changeTax(uint256 taxVal) external onlyOwner() {
        require(taxVal <= 30 && taxVal >= 0, "New tax value must be between 0 and 30.");
        _taxAmount = taxVal;
    }
    
    function changeArenaManager(address payable arenaManager) external onlyOwner() {
        _arenaManager = arenaManager;
        AM = ArenaManager(arenaManager);
    }

    function changeMinTokensForSwap(uint256 newMin) external onlyOwner() {
        _minTokensForSwap = newMin;
    }

    function changeWBNB(address newWBNB) external onlyOwner() {
        _wbnb = newWBNB;
        _wbnbPath = [address(this), _wbnb];
    }

    function changeBUSD(address newBUSD) external onlyOwner() {
        _busd = newBUSD;
        _busdPath = [_wbnb, _busd];
    }

    function changePair(address pair) external onlyOwner() {
        _pair = pair;
    }

    function changeRouter(address router) external onlyOwner() {
        _router = router;
        _routerInterface = IPancakeRouter02(_router);
    }

    function changeMarketing(address payable marketing) external onlyOwner() {
        _marketingWallet = marketing;
    }

    function taxSwitch() external onlyOwner() {
        _taxOn = !_taxOn;
    }

    function _feeSwap() private {

        _taxOn = false; //stops recurssion

        //@dev calc how many tokens we need to sell

        uint256 tokenBal = _balances[address(this)];

        uint256 tokensForLP = tokenBal.div(_lpShareDiv);

        uint256 tokensToSell = tokenBal.sub(tokensForLP);

        _approve(address(this), _router, tokenBal);

        //@dev sell tokens for BNB
                
        routerInterface.swapExactTokensForETHSupportingFeeOnTransferTokens(
        tokensToSell,
        0,
        _path,
        address(this),
        block.timestamp
        );

        uint256 bnbBalance = address(this).balance;

        //@dev add liquidity

        uint256 bnbForLP = bnbBalance.mul(_lpShare).div(10000);

        routerInterface.addLiquidityETH{value: bnbForLP}(
        address(this),
        tokensForLP,
        0,
        0,
        _marketingWallet,
        block.timestamp //maybe need to add some?
        );

        uint256 bnbToBUSD = bnbBalance.mul(_prizePoolShare).div(10000);

        _routerInterface.swapExactETHForTokens{value: bnbToBUSD}(
        0,
        _busdPath,
        _arenaManager,
        block.timestamp + 300);

        _arenaManager.transfer(bnbBalance.mul(_amShare).div(10000)); //send money to arena manager
        
        _marketingWallet.transfer(address(this).balance); //send remaining to marketing
        
        _taxOn = true;
        
    }


    //@dev custom transfer and approve funcs

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(address sender, address recipient, uint256 amount) private {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        

        if (_taxOn && !_exclude[sender] && !_excluded[recipient] && (sender == _pair || recipient == _pair)) {
            uint256 fee = amount.div(100).mul(_taxAmount);

            _balances[address(this)] = _balances[address(this)].add(fee);
            _balances[sender] = _balances[sender].sub(fee);

            emit Transfer(sender, address(this), fee);

            amount = amount.sub(fee);
        }

        if (sender != _pair && _balances[address(this)] >= _minTokensForSwap) {
            _feeSwap();
        }

        _balances[recipient] = _balances[recipient].add(amount);
        _balances[sender] = _balances[sender].sub(amount);

        emit Transfer(sender, recipient, amount);

        if (sender == _pair && recipient != _arenaManager) {
            AM.contenderBuy(amount);
        } else if (sender != _arenaManager && recipient == _pair) {
            AM.contenderSell(amount);
        }

    }

    //@dev standard ERC20 funcs

    function totalSupply() pure external override returns (uint256) {
        return _total;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }


    //@dev custom view funcs for information


}
