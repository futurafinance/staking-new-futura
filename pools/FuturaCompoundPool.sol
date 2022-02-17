// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.5;

import "./AutoCompoundPool.sol";

contract FuturaCompoundPool is AutoCompoundPool {
    uint256 public processingFeesThreshold = 500000000000000000 wei;
    address public processingFeesDestination;

    constructor(IFutura futura, IFuturaLinkFuel fuel, IInvestor investor, address processingFeeDestination, address routerAddress, IBEP20 _outToken) AutoCompoundPool(futura, fuel, investor, routerAddress, _outToken) { 
        setProcessingFeesDestination(processingFeeDestination);
    }

    function doProcessFunds(uint256 gas) internal override {
        super.doProcessFunds(gas);

        if (processingFees >= processingFeesThreshold) {
            uint256 burnAmount = processingFees * 25 / 100;
            feeTokens += burnAmount;
            futura.transfer(processingFeesDestination, processingFees - burnAmount);
            delete processingFees;
        }
    }
    
    function setProcessingFeesThreshold(uint256 threshold) external onlyOwner {
        require(threshold > 0, "Futura Pool: Invalid value");
        processingFeesThreshold = threshold;
    }

    function setProcessingFeesDestination(address destination) public onlyOwner {
        require(destination != address(0), "Futura Pool: Invalid address");
        processingFeesDestination = destination;
    }

    function approvePancake() external onlyOwner {
        outToken.approve(address(_pancakeswapV2Router), ~uint256(0));
    }
}