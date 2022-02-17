// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.5;

import "./../FuturaLinkComponent.sol";
import "./../interfaces/IMasterChef.sol";
import "./../interfaces/IFuturaLink.sol";
import "./../interfaces/IFuturaLinkPool.sol";
import "./../interfaces/IPancakePair.sol";
import "./../interfaces/IPancakeRouterV2.sol";
import "./../interfaces/IInvestor.sol";

contract FuturaLinkPool is IFuturaLinkPool, FuturaLinkComponent {
    struct UserInfo {
        uint256 totalStakeAmount;
        uint256 totalValueClaimed;
        uint256 lastStakeTime;

        uint256 lastDividend;
        uint256 unclaimedDividends;
        uint256 earned;
    }

    uint256 public constant DIVIDEND_ACCURACY = TOTAL_SUPPLY;
    IInvestor public investor;

    IBEP20 public outToken;
    IBEP20 public inToken;
    
    uint256 public amountOut;
    uint256 public amountIn;
    uint256 public totalDividends; 
    uint256 public totalDividendAmount;
    bool public override isStakingEnabled;
    uint256 public override earlyUnstakingFeeDuration = 1 days;
    uint16 public override unstakingFeeMagnitude = 10;

    uint256 public disburseBatchDivisor;
    uint256 public disburseBatchTime;
    uint256 public dividendPointsToDisbursePerSecond;
    uint256 public lastAvailableDividentAmount;
    uint256 public disburseDividendsTimespan = 2 hours;

    mapping(address => UserInfo) public userInfo;

    uint256 public totalStaked;

    uint256 public feeTokens;
    uint16 public fundAllocationMagnitude = 600;

    address internal _pancakeSwapRouterAddress;
    IPancakeRouter02 public _pancakeswapV2Router;
    IPancakePair internal outTokenPair;

    address internal constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    uint256 internal constant TOTAL_SUPPLY = 1000000000000 * 10**9;

    uint256 internal futuralinkPointsPrecision;
    
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);
    event Burned(uint256 amount);

    constructor(IFutura futura, IFuturaLinkFuel _fuel, IInvestor _investor, address routerAddress, IBEP20 _inToken, IBEP20 _outToken) FuturaLinkComponent(futura, _fuel) {
        inToken = _inToken;
        outToken = _outToken;
        investor = _investor;
        isStakingEnabled = true;
        
        setPancakeSwapRouter(routerAddress);
    }

    receive() external payable { }

    function stakeAll() external notPaused process { 
        doStake(msg.sender, inToken.balanceOf(msg.sender) - 1 * 10**futura.decimals());
    }

    function stake(uint256 amount) external notPaused process { 
        if (unclaimedDividendsOf(msg.sender) > 0) {
            doClaim(msg.sender);
        }
        doStake(msg.sender, amount);
    }

    function stake(address userAddress, uint256 amount) external onlyAdmins {
        doStake(userAddress, amount);
    }

    function unstakeAll() external notPaused process { 
        UserInfo storage user = userInfo[msg.sender];
        doUnstake(msg.sender, user.totalStakeAmount);
    }

    function unstake(uint256 amount) external notPaused process {
        if (unclaimedDividendsOf(msg.sender) > 0) {
            doClaim(msg.sender);
        }
        doUnstake(msg.sender, amount);
    }

    function unstake(address userAddress, uint256 amount) external onlyAdmins {
        doUnstake(userAddress, amount);
    }

    function stakeOnBehalf(address userAddress, uint256 amount) external onlyAdmins {
        doStake(msg.sender, userAddress, amount);
    }

    function deposit(uint256 amount, uint256 gas) external payable virtual override onlyAdmins {
        if (amount > 0) {
            require(outToken.allowance(msg.sender, address(this)) >= amount, "FuturaLinkPool: Not allowed");
            outToken.transferFrom(msg.sender, address(this), amount);
            onDeposit(amount);
        }

        if (gas > 0) {
            doProcessFunds(gas);
        }
    }

    function claim() external notPaused process { //put authorized
        doClaim(msg.sender);
    }

    function claim(address userAddress) external onlyAdmins {
        doClaim(userAddress);
    }

    function claimFor(address userAddress) external onlyAdmins {
        // Required to allow auto-compound to other pools
        doClaim(userAddress, msg.sender);
    }

    function amountStakedBy(address userAddress) public view returns (uint256) {
        return userInfo[userAddress].totalStakeAmount;
    }

    function unclaimedDividendsOf(address userAddress) public view returns (uint256) {
        UserInfo storage user = userInfo[userAddress];
        return (user.unclaimedDividends + calculateReward(user)) / DIVIDEND_ACCURACY;
    }

    function unclaimedValueOf(address userAddress) public override view returns (uint256) {
        UserInfo storage user = userInfo[userAddress];
        uint256 unclaimedDividends = (user.unclaimedDividends + calculateReward(user)) / DIVIDEND_ACCURACY;
        return valueOfOutTokens(unclaimedDividends);
    }

    function totalValueClaimed(address userAddress) public override view returns(uint256) {
        return userInfo[userAddress].totalValueClaimed;
    }

    function totalEarnedBy(address userAddress) public view returns (uint256) {
        UserInfo storage user = userInfo[userAddress];
        return (user.earned + calculateReward(user)) / DIVIDEND_ACCURACY;
    }

    function excessTokens(address tokenAddress) public virtual view returns(uint256) {
        uint256 balance = (IBEP20(tokenAddress)).balanceOf(address(this));

        if (tokenAddress == address(inToken)) {
            balance -= totalStaked + feeTokens;
        }

        if (tokenAddress == address(outToken)) {
            balance -= amountOut;
        }

        return balance;
    }

    function disburse(uint256 amount) external onlyAdmins {
        uint256 excess = excessTokens(address(outToken));
        require(amount <= excess, "FuturaLink: Excessive amount");
        onDeposit(amount);
    }

    function doProcessFunds(uint256) virtual internal {
        uint256 balance = address(this).balance;
        uint256 availableFundsForTokens =  balance * fundAllocationMagnitude / 1000;
        uint256 availableFundsForInvestor = balance - availableFundsForTokens;
        
        // Fill pool with token
        if (availableFundsForTokens > 0) {
            onDeposit(buyOutTokens(availableFundsForTokens));
        }
        
        // //Fill the investor 
        if (availableFundsForInvestor > 0) {
            payable(address(investor)).transfer(availableFundsForInvestor);
        }
    }

    function doStake(address userAddress, uint256 amount) internal {
        doStake(userAddress, userAddress, amount);
    }

    function doStake(address spender, address userAddress, uint256 amount) internal {
        require(amount > 0, "FuturaLinkPool: Invalid amount");
        require(isStakingEnabled, "FuturaLinkPool: Disabled");

        fillPoolInternal(); //Use staking / unstake to fill the pool
        updateStakingOf(userAddress);

        require(inToken.balanceOf(spender) > amount, "FuturaLinkPool: Insufficient balance");
        require(inToken.allowance(spender, address(this)) >= amount, "FuturaLinkPool: Not approved");
 
        UserInfo storage user = userInfo[userAddress];

        user.lastStakeTime = block.timestamp;
        user.totalStakeAmount += amount;
        amountIn += amount;
        totalStaked += amount;
        updateDividendsBatch();

        inToken.transferFrom(spender, address(this), amount);
        emit Staked(userAddress, amount);
    }
    
    function doUnstake(address userAddress, uint256 amount) internal {
        require(amount > 0, "FuturaLinkPool: Invalid amount");
        
        fillPoolInternal(); //Use staking / unstake to fill the pool
        updateStakingOf(userAddress);

        UserInfo storage user = userInfo[userAddress];
        require(user.totalStakeAmount >= amount, "FuturaLinkPool: Excessive amount");

        user.totalStakeAmount -= amount;
        amountIn -= amount;
        totalStaked -= amount;
        updateDividendsBatch();

        uint256 feeAmount;
        if (block.timestamp - user.lastStakeTime < earlyUnstakingFeeDuration) {
           feeAmount = amount * unstakingFeeMagnitude / 1000;
           feeTokens += feeAmount;
        }
        
        inToken.transfer(userAddress, amount - feeAmount);
        emit Unstaked(userAddress, amount);
    }

    function doClaim(address userAddress) private {
        doClaim(userAddress, userAddress);
    }

    function doClaim(address userAddress, address receiver) private {
        updateStakingOf(userAddress);

        UserInfo storage user = userInfo[userAddress];

        uint256 reward = user.unclaimedDividends / DIVIDEND_ACCURACY;
        require(reward > 0, "FuturaLinkPool: Nothing to claim");

        user.unclaimedDividends -= reward * DIVIDEND_ACCURACY;
        user.totalValueClaimed += valueOfOutTokens(reward);
        
        amountOut -= reward;
        sendReward(receiver, reward);
    }

    function sendReward(address userAddress, uint256 reward) internal virtual {
        outToken.transfer(userAddress, reward);
    }

    function onDeposit(uint256 amount) internal {
        if (amountIn == 0) {
            //Excess of tokens
            return;
        }

        amountOut += amount;
        totalDividends += amount;

        // Gradually handout a new batch of dividends
        lastAvailableDividentAmount = totalAvailableDividendPoints();
        disburseBatchTime = block.timestamp;

        totalDividendAmount += amount * DIVIDEND_ACCURACY / amountIn;

        dividendPointsToDisbursePerSecond = (totalDividendAmount - lastAvailableDividentAmount) / disburseDividendsTimespan;
        disburseBatchDivisor = amountIn;
    }

    function fillPool() public onlyAdmins {
        require(futura.isRewardReady(address(this)), "Pool claim is not ready");
        uint256 previousBalanceOut = outToken.balanceOf(address(this));
        futura.claimReward(address(this));
        uint256 incomingBalanceOut = outToken.balanceOf(address(this)) - previousBalanceOut;
        if (incomingBalanceOut > 0) {
            onDeposit(incomingBalanceOut);
        }
    }

    function fillPoolInternal() internal {
        if (futura.isRewardReady(address(this))) {
            uint256 previousBalanceOut = outToken.balanceOf(address(this));
            futura.claimReward(address(this));
            uint256 incomingBalanceOut = outToken.balanceOf(address(this)) - previousBalanceOut;
            if (incomingBalanceOut > 0) {
                onDeposit(incomingBalanceOut);
            }
        }
    }

    function processAllFunds() public onlyAdmins {
        doProcessFunds(address(this).balance);
    }

    function updateDividendsBatch() internal {
        if (amountIn == 0) {
            return;
        }

        lastAvailableDividentAmount = totalAvailableDividendPoints();
        disburseBatchTime = block.timestamp;

        uint256 remainingPoints = totalDividendAmount - lastAvailableDividentAmount;
        if (remainingPoints == 0) {
            return;
        }

        totalDividendAmount = totalDividendAmount + (remainingPoints * disburseBatchDivisor / amountIn) - remainingPoints;
        dividendPointsToDisbursePerSecond = (totalDividendAmount - lastAvailableDividentAmount) / (disburseDividendsTimespan - (block.timestamp - disburseBatchTime));

        disburseBatchDivisor = amountIn;
    }

    function totalAvailableDividendPoints() internal view returns(uint256) {
        uint256 points = lastAvailableDividentAmount + (block.timestamp - disburseBatchTime) * dividendPointsToDisbursePerSecond;
        if (points > totalDividendAmount) {
            return totalDividendAmount;
        }

        return points;
    }

    function updateStakingOf(address userAddress) internal {
        UserInfo storage user = userInfo[userAddress];

        uint256 reward = calculateReward(user);

        user.unclaimedDividends += reward;
        user.earned += reward;
        user.lastDividend = totalAvailableDividendPoints();
    }

    function calculateReward(UserInfo storage user) private view returns (uint256) {
        return (totalAvailableDividendPoints() - user.lastDividend) * user.totalStakeAmount;
    }
    
    function buyOutTokens(uint256 weiFunds) internal virtual returns(uint256) { 
        address[] memory path = new address[](2);
        path[0] = _pancakeswapV2Router.WETH();
        path[1] = address(outToken);

        uint256 previousBalance = outToken.balanceOf(address(this));
        _pancakeswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{ value: weiFunds }(0, path, address(this), block.timestamp + 360);
        return outToken.balanceOf(address(this)) - previousBalance;
    }

    function valueOfOutTokens(uint256 amount) internal virtual view returns (uint256) {
        (uint112 reserve0, uint112 reserve1, ) = outTokenPair.getReserves();

        // Ensure reserve0 is WETH
        (uint112 _reserve0, uint112 _reserve1) = outTokenPair.token0() == _pancakeswapV2Router.WETH() ? (reserve0, reserve1) : (reserve1, reserve0);
        if (_reserve1 == 0) {
            return _reserve0;
        }

        return amount * _reserve0 / _reserve1;
    }

    function setEarlyUnstakingFeeDuration(uint256 duration) external onlyOwner {  
        earlyUnstakingFeeDuration = duration;
    }

    function setUnstakingFeeMagnitude(uint16 magnitude) external onlyOwner {
        require(unstakingFeeMagnitude <= 1000, "FuturaLinkPool: Out of range");
        unstakingFeeMagnitude = magnitude;
    }

    function setFundAllocationMagnitude(uint16 magnitude) external onlyOwner {  
        require(magnitude <= 1000, "FuturaLinkPool: Out of range");
        fundAllocationMagnitude = magnitude;
    }

    function setPancakeSwapRouter(address routerAddress) public onlyOwner {
        require(routerAddress != address(0), "FuturaLinkPool: Invalid address");

        _pancakeSwapRouterAddress = routerAddress; 
        _pancakeswapV2Router = IPancakeRouter02(_pancakeSwapRouterAddress);

        outTokenPair = IPancakePair(IPancakeFactory(_pancakeswapV2Router.factory()).getPair(_pancakeswapV2Router.WETH(), address(outToken)));
    }

    function setDisburseDividendsTimespan(uint256 timespan) external onlyOwner {
        require(timespan > 0, "FuturaLinkPool: Invalid value");
        
        disburseDividendsTimespan = timespan;
        onDeposit(0);
    }

    function outTokenAddress() external view override returns (address) {
        return address(outToken);
    }

    function inTokenAddress() external view override returns (address) {
        return address(inToken);
    }
}