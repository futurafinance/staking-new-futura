// SPDX-License-Identifier: MIT

pragma solidity ^0.8.5;

import "./../interfaces/IMasterChef.sol";
import "./../interfaces/IInvestor.sol";
import "./../interfaces/IFundingPlan.sol";
import "./../interfaces/IFutura.sol";
import "./../utils/AccessControlled.sol";
import "./../utils/PancakeSwapHelper.sol";
import "./../utils/EmergencyWithdrawable.sol";

contract CakeInvestmentPlan is IFundingPlan, PancakeSwapHelper, EmergencyWithdrawable {
    IMasterChef public masterChef;
    IBEP20 public cake;
    
    uint256 public totalStaked;
    uint256 public totalProfitsBNB;
    address public profitsDestination;
    uint256 public nextWithdrawDate;
    uint256 public withdrawPeriod = 2 hours;

    event Withdrawn(uint256 cakeAmount, uint256 bnbAmount);
    event Staked(uint256 cakeAmount);

    constructor(IBEP20 _cake, IMasterChef _masterChef, address routerAddress, address profitDestination, uint256 previousTotalProfits) PancakeSwapHelper(routerAddress) {
        setCakeOptions(_cake, _masterChef);
        setProfitsDestination(profitDestination);

        nextWithdrawDate = block.timestamp + withdrawPeriod;
        totalProfitsBNB = previousTotalProfits;
    }

    function deposit() external override payable {
        if (address(this).balance == 0) {
            return;
        }

        uint256 cakeAmount = swapBNBForTokens(address(this).balance, cake, address(this));
        doStake(cakeAmount);

        if (nextWithdrawDate <= block.timestamp) {
            nextWithdrawDate = block.timestamp + withdrawPeriod;
            doWithdrawProfits();
        }
    }

    function stakeCakeBalance() external onlyAdmins {
        uint256 cakeBalance = cake.balanceOf(address(this));
        if (cakeBalance > 0) {
            doStake(cakeBalance);
        }
    }

    function withdrawProfits() external onlyAdmins {
        doWithdrawProfits();
    }

    function withdrawAll() external onlyAdmins {
        masterChef.leaveStaking(totalStaked);
        delete totalStaked;
    }

    function pendingProfits() external view returns(uint256) {
        return masterChef.pendingCake(0, address(this));
    }

    function setCakeOptions(IBEP20 _cake, IMasterChef _masterChef) public onlyOwner {
        require(address(_masterChef) != address(0), "Investor: Invalid address");
        require(address(_cake) != address(0), "Investor: Invalid address");

        cake = _cake;
        masterChef = _masterChef;
        cake.approve(address(_masterChef), ~uint256(0));
    }

    function setProfitsDestination(address destination) public onlyOwner {
        require(destination != address(0), "CakeInvestmentPlan: Invalid address");
        profitsDestination = destination;
    }
    
    function doStake(uint256 cakeAmount) internal {
        masterChef.enterStaking(cakeAmount);
        totalStaked += cakeAmount;
        emit Staked(cakeAmount);
    }

    function doWithdrawProfits() private {
        require(profitsDestination != address(0), "CakeInvestmentPlan: Not enabled");
        
        masterChef.leaveStaking(0);

        uint256 cakeBalance = cake.balanceOf(address(this));
        if (cakeBalance > 0) {
            uint256 bnb = swapTokensForBNB(cakeBalance, cake, profitsDestination);
            totalProfitsBNB += bnb;
            emit Withdrawn(cakeBalance, bnb);
        }
    }

    function setWithdrawPeriod(uint256 period) external onlyOwner {
        withdrawPeriod = period;
    }

    function setNextWithdrawDate(uint256 date) external onlyOwner {
        nextWithdrawDate = date;
    }

    function approveCake() external onlyOwner {
        cake.approve(_pancakeSwapRouterAddress, ~uint256(0));
    }
    
    receive() external payable { }
}