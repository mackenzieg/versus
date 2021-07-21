pragma solidity 0.6.12;

import "./libraries/TransferHelper.sol";
import "./libraries/IERC20.sol";
import "./libraries/SafeMath.sol";
import "./libraries/Privileged.sol";
import "./libraries/Address.sol";
import "./libraries/IPancake.sol";
import "./IArenaManager.sol";
//import "./ArenaManager.sol";

interface IDividendPayingToken {
  function setBalance(address payable account, uint256 newBalance) external;
  function process(uint256 gas) external returns (uint256, uint256, uint256);
  function excludeFromDividends(address account) external;

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

contract Contender is Context, IERC20, Privileged {
    using SafeMath for uint256;
    using Address for address;

    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;
   
    uint256 private constant _total = 10**9 * 10**9; //1B Total Supply

    uint256 public _taxAmount = 10;

    //@dev 5% prize pool, 2% auto-lp, 2% marketing, 1% arena manager. weird math to fit all fees into one swap.


    // These are out of 100
    uint256 private _lpPercentage = 20;
    uint256 private _prizePoolPercentage = 50;
    uint256 private _mmPercentage = 10;        
    uint256 private _marketingPercentage = 20;        

    uint256 public _minTokensForSwap = _total.mul(5).div(1000); //500k Tokens
    bool public _taxOn = false;
    
    address payable private _arenaManager;
    IArenaManager private AM;

    address payable private _dividendTracker;
    IDividendPayingToken private DT;
    
    address public _pair = address(0);
    address private _router;
    address private _wbnb;
    address private _busd;
    bool private swapAndLiqEnabled = false;
    bool inSwapAndLiquify;

    IPancakeRouter02 _routerInterface;
    IPancakePair _pairInterface;

    address[] private _wbnbPath = [address(this), _wbnb];
    address[] private _busdPath = [address(this), _wbnb, _busd];

    mapping (address => bool) _excluded;
 
    address payable private _marketingWallet = 0x1366b918Fb5b78c6cf574f32B304255B3A3C8060;

    address payable public deadAddress = payable(0x000000000000000000000000000000000000dEaD);

    string private _name;
    string private _symbol;
    uint8 private _decimals = 9;

    event ProcessedDividendTracker(
        uint256 iterations,
        uint256 claims,
        uint256 lastProcessedIndex,
        bool indexed automatic,
        uint256 gas,
        address indexed processor
    );

    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    constructor (address payable arenaManager, address payable dividendTracker, address router, address wbnb, address busd,
        string memory name, string memory symbol) public {
        _arenaManager = arenaManager;

        _router = router;
        _wbnb = wbnb;
        _busd = busd;
        _busdPath = [address(this), _wbnb, _busd];
        _wbnbPath = [address(this), _wbnb];
        _routerInterface = IPancakeRouter02(router);

        IPancakeFactory pcFactory = IPancakeFactory(_routerInterface.factory());
        _pair = pcFactory.createPair(address(this), _wbnb);
        _pairInterface = IPancakePair(_pair);

        AM = IArenaManager(arenaManager);
        DT = IDividendPayingToken(dividendTracker);

        _name = name;
        _symbol = symbol;

        _balances[_msgSender()] = _total;
        emit Transfer(address(0), _msgSender(), _total);
    }

    receive() external payable {}

    function getPair() public view returns (address) {
        return _pair;
    }

    function setDividendTracker(address payable dividendTracker) external onlyPriviledged() {
        _dividendTracker = dividendTracker;
        DT = IDividendPayingToken(dividendTracker);

        updatePriviledged(_arenaManager, dividendTracker);

        DT.excludeFromDividends(_arenaManager);
        DT.excludeFromDividends(_router);
        DT.excludeFromDividends(deadAddress);
    }

    function getDividendTrackerContract() external view returns (address payable) {
        return _dividendTracker;
    }

    function addExcluded(address addr) external onlyPriviledged() {
        _excluded[addr] = true;
    }

    function removeExcluded(address addr) external onlyPriviledged() {
        _excluded[addr] = false;
    }

    function getTaxShares() public view returns(uint256, uint256, uint256, uint256) {
        return (_prizePoolPercentage, _marketingPercentage, _lpPercentage, _mmPercentage);
    }

    function changeTaxShares(uint256 pp, uint256 mp, uint256 lp, uint256 mm) external onlyPriviledged() {
        _prizePoolPercentage = pp; 
        _marketingPercentage = mp;
        _lpPercentage = lp;
        _mmPercentage = mm;
    }
    
    function changeTax(uint256 taxVal) external onlyPriviledged() {
        require(taxVal <= 45 && taxVal >= 0, "New tax value must be between 0 and 45.");
        _taxAmount = taxVal;
    }

    function getTaxes() public view returns (uint256) {
        return _taxAmount;
    }
    
    function changeArenaManager(address payable arenaManager) external onlyPriviledged() {
        _arenaManager = arenaManager;
        AM = IArenaManager(arenaManager);

        updatePriviledged(_arenaManager, _dividendTracker);

        DT.excludeFromDividends(arenaManager);
    }

    function getArenaManager() external view returns (address) {
        return _arenaManager;
    }

    function changeMinTokensForSwap(uint256 newMin) external onlyPriviledged() {
        _minTokensForSwap = newMin;
    }

    function changeWBNB(address newWBNB) external onlyPriviledged() {
        _wbnb = newWBNB;
        _wbnbPath = [address(this), _wbnb];
    }

    function changeBUSD(address newBUSD) external onlyPriviledged() {
        _busd = newBUSD;
        _busdPath = [_wbnb, _busd];
    }

    function changePair(address pair) external onlyPriviledged() {
        _pair = pair;
    }

    function changeRouter(address router) external onlyPriviledged() {
        _router = router;
        _routerInterface = IPancakeRouter02(_router);
    }

    function changeMarketing(address payable marketing) external onlyPriviledged() {
        _marketingWallet = marketing;
    }

    function setTax(bool tax) external onlyPriviledged() {
        _taxOn = tax;
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _routerInterface.WETH();

        _approve(address(this), address(_routerInterface), tokenAmount);

        // make the swap
        _routerInterface.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this), // The contract
            block.timestamp
        );

        //emit SwapTokensForETH(tokenAmount, path);
    }

    function swapETHForTokens(uint256 amount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = _routerInterface.WETH();
        path[1] = address(this);

        // make the swap
        _routerInterface.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amount}(
            0, // accept any amount of Tokens
            path,
            deadAddress, // Burn address
            block.timestamp.add(600)
        );

        //emit SwapETHForTokens(amount, path);
    }

    function swapAndLiquify(uint256 contractTokenBalance) private {

        swapAndLiqEnabled = false;

        // ------------- Auto LP ---------------
        // LP Token amounts
        uint256 lpTokens = contractTokenBalance.mul(_lpPercentage).div(100);

        uint256 half = lpTokens.div(2);
        uint256 otherHalf = lpTokens.sub(half);

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // swap tokens for ETH
        swapTokensForEth(half); // <- this breaks the ETH -> HATE swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);

        // add liquidity to uniswap
        addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);

        // ------------- Prize ---------------

        uint256 giveAwayTokens = contractTokenBalance.mul(_prizePoolPercentage).div(100);


        _approve(address(this), address(_routerInterface), giveAwayTokens);
        _routerInterface.swapExactTokensForTokens(giveAwayTokens, 0, _busdPath, _arenaManager, block.timestamp + 300);
        
        
        // ------------- Middleman ---------------
        uint256 middleManTokens = contractTokenBalance.mul(_mmPercentage).div(100);
        initialBalance = address(this).balance;

        swapTokensForEth(middleManTokens);

        newBalance = address(this).balance.sub(initialBalance);
        
        _arenaManager.transfer(newBalance);

        // ------------- Marketing ---------------
        uint256 marketingTokens = contractTokenBalance.sub(lpTokens).sub(giveAwayTokens).sub(middleManTokens);

        initialBalance = address(this).balance;

        swapTokensForEth(marketingTokens);

        newBalance = address(this).balance.sub(initialBalance);
        
        _marketingWallet.transfer(newBalance);

        swapAndLiqEnabled = true;
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) public {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(_routerInterface), tokenAmount);

        // add the liquidity
        _routerInterface.addLiquidityETH{value: ethAmount} (
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp + 300
        );
    }

    //@dev custom transfer and approve funcs

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function getSwapAndLiqEnabled() external view returns (bool) {
        return swapAndLiqEnabled;
    }
     
    function setSwapAndLiqEnabled(bool _swapAndLiqEnabled) external onlyPriviledged() {
         swapAndLiqEnabled = _swapAndLiqEnabled;
    }

    function _transfer(address sender, address recipient, uint256 amount) private {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        if (_taxOn && !_excluded[sender] && !_excluded[recipient] && (sender == _pair || recipient == _pair)) {
            uint256 fee = amount.div(100).mul(_taxAmount);

            _balances[address(this)] = _balances[address(this)].add(fee);
            _balances[sender] = _balances[sender].sub(fee);

            emit Transfer(sender, address(this), fee);

            amount = amount.sub(fee);
        }

        if (recipient == _pair && balanceOf(address(this)) >= _minTokensForSwap && swapAndLiqEnabled) {

            uint256 swapAmount = _minTokensForSwap;
            swapAndLiquify(swapAmount);
        }

        _balances[recipient] = _balances[recipient].add(amount);
        _balances[sender] = _balances[sender].sub(amount);

        emit Transfer(sender, recipient, amount);

        // Update giveaway trackers
        DT.setBalance(payable(sender), balanceOf(sender));
        DT.setBalance(payable(recipient), balanceOf(recipient));
        //try _dividendTracker.setBalance(payable(from), balanceOf(from)) {} catch {} 
        //try _dividendTracker.setBalance(payable(to), balanceOf(to)) {} catch {} 

        if (sender == _pair && (recipient != _arenaManager && recipient != address(this))) {
            AM.contenderBuy(amount);
        } else if ((sender != _arenaManager && sender != address(this)) && recipient == _pair ) {
            AM.contenderSell(amount);
        }
    }

    //@dev standard ERC20 funcs

    function totalSupply() public view override returns (uint256) {
        return _total;
    }

    function balanceOf(address account) public view override returns (uint256) {
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

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function deanAnnounceWinner(uint256 gas) external onlyPriviledged() {

        uint256 busdBal = IERC20(_busd).balanceOf(address(DT));

        DT.distributeBusdDividends(busdBal);

       	try DT.process(gas) returns (uint256 iterations, uint256 claims, uint256 lastProcessedIndex) {
            // TODO change name of this event 
	    		  emit ProcessedDividendTracker(iterations, claims, lastProcessedIndex, true, gas, tx.origin);
	    	}
	    	catch {
	    	}
    }
}
