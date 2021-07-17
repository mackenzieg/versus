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
    IArenaManager private AM;

    address payable private _dividendTracker;
    IDividendPayingToken private DT;
    
    
    address private _pair = address(0);
    address private _router;
    address private _wbnb;
    address private _busd;

    IPancakeRouter02 _routerInterface = IPancakeRouter02(_router);

    address[] private _wbnbPath = [address(this), _wbnb];
    address[] private _busdPath = [_wbnb, _busd];

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

    constructor (address payable arenaManager, address payable dividendTracker, address router, address wbnb, address busd,
        string memory name, string memory symbol) public {
        _arenaManager = arenaManager;

        _router = router;
        _wbnb = wbnb;
        _busd = busd;

        AM = IArenaManager(arenaManager);
        DT = IDividendPayingToken(dividendTracker);

        _name = name;
        _symbol = symbol;

        _balances[_msgSender()] = _total;
        emit Transfer(address(0), _msgSender(), _total);
    }

    function setDividendTracker(address payable dividendTracker) external onlyPriviledged() {
        _dividendTracker = dividendTracker;
        DT = IDividendPayingToken(dividendTracker);

        updatePriviledged(_arenaManager, dividendTracker);

        DT.excludeFromDividends(_arenaManager);
        DT.excludeFromDividends(_router);
        DT.excludeFromDividends(deadAddress);
    }

    function getDividendTrackerContract() external returns (address payable) {
        return _dividendTracker;
    }

    function addExcluded(address addr) external onlyPriviledged() {
        _excluded[addr] = true;
    }

    function removeExcluded(address addr) external onlyPriviledged() {
        _excluded[addr] = false;
    }

    function changeTaxShares(uint256 pp, uint256 lp, uint256 am) external onlyPriviledged() {
        _prizePoolShare = pp; 
        _lpShare = lp;
        _amShare = am;
    }
    
    function changeTax(uint256 taxVal) external onlyPriviledged() {
        require(taxVal <= 30 && taxVal >= 0, "New tax value must be between 0 and 30.");
        _taxAmount = taxVal;
    }
    
    function changeArenaManager(address payable arenaManager) external onlyPriviledged() {
        _arenaManager = arenaManager;
        AM = IArenaManager(arenaManager);

        updatePriviledged(_arenaManager, _dividendTracker);

        DT.excludeFromDividends(arenaManager);
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

    function taxSwitch() external onlyPriviledged() {
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
                
        _routerInterface.swapExactTokensForETHSupportingFeeOnTransferTokens(
        tokensToSell,
        0,
        _wbnbPath,
        address(this),
        block.timestamp
        );

        uint256 bnbBalance = address(this).balance;

        //@dev add liquidity

        uint256 bnbForLP = bnbBalance.mul(_lpShare).div(10000);

        _routerInterface.addLiquidityETH{value: bnbForLP}(
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
        

        if (_taxOn && !_excluded[sender] && !_excluded[recipient] && (sender == _pair || recipient == _pair)) {
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

        // Update giveaway trackers
        // TODO the dividend contract has onlyOwner which will fail here
        DT.setBalance(payable(sender), balanceOf(sender));
        DT.setBalance(payable(recipient), balanceOf(recipient));
        //try _dividendTracker.setBalance(payable(from), balanceOf(from)) {} catch {} 
        //try _dividendTracker.setBalance(payable(to), balanceOf(to)) {} catch {} 

        if (sender == _pair && recipient != _arenaManager) {
            AM.contenderBuy(amount);
        } else if (sender != _arenaManager && recipient == _pair) {
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

    function deanAnnounceWinner(uint256 gas) external {
        require(_msgSender() == _arenaManager, "Only SpaceDean can announce a winner");
       	try DT.process(gas) returns (uint256 iterations, uint256 claims, uint256 lastProcessedIndex) {
            // TODO change name of this event 
	    		  emit ProcessedDividendTracker(iterations, claims, lastProcessedIndex, true, gas, tx.origin);
	    	}
	    	catch {
	    	}
    }
}
