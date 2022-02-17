// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.5;

import "./StakeFuturaPool.sol";

contract AutoCompoundPool is StakeFuturaPool {

    address[] public autoCompoundAddresses;
    mapping(address => uint256) public autoCompoundIndices;
    uint256 public autoCompoundIndex;

    bool public isAutoCompoundAvailable = true;

    uint256 public processingFeeMagnitude = 5;
    uint256 public processingFees;
    uint256 public minEarningsToAutoCompound = 1000 * 10**9;

    event AutoCompoundStatusChanged(address indexed user, bool isEnabled);
    event AutoCompounded(address indexed user, uint256 amount);

    constructor(IFutura futura, IFuturaLinkFuel fuel, IInvestor investor, address routerAddress, IBEP20 _outToken) StakeFuturaPool(futura, fuel, investor, routerAddress, _outToken) {
        
    }

    function compound() external notPaused notUnauthorizedContract process {
        doAutoCompound(msg.sender);
    }

    function compound(address userAddress) external onlyAdmins {
        doAutoCompound(userAddress);
    }

    function processAutoCompound(uint256 gas) external onlyAdmins {
        doProcessAutoCompound(gas);
    }

    function doProcessFunds(uint256 gas) internal override virtual {
        super.doProcessFunds(gas);

        if (isAutoCompoundAvailable && isStakingEnabled && gas > 0) {
            doProcessAutoCompound(gas);
        }
    }

    function doProcessAutoCompound(uint256 gas) internal {
        uint256 gasUsed ;
        uint256 gasLeft = gasleft();
        uint256 iteration;
        uint256 userIndex = autoCompoundIndex; 

        while(gasUsed < gas && iteration < autoCompoundAddresses.length) {
            if (userIndex >= autoCompoundAddresses.length) {
                userIndex = 0;
            }

            doAutoCompound(autoCompoundAddresses[userIndex]);
           
           unchecked {
                uint256 newGasLeft = gasleft();

                if (gasLeft > newGasLeft) {
                    gasUsed += gasLeft - newGasLeft;
                    gasLeft = newGasLeft;
                }

                iteration++;
                userIndex++;
            }
        }

        autoCompoundIndex = userIndex;
    }

    function doAutoCompound(address userAddress) internal { 
        updateStakingOf(userAddress);

        UserInfo storage user = userInfo[userAddress];
        uint256 reward = user.unclaimedDividends / DIVIDEND_ACCURACY;
        if (reward < minEarningsToAutoCompound) {
            return;
        }

        // Claim
        user.unclaimedDividends -= reward * DIVIDEND_ACCURACY;
        amountOut -= reward;

        uint256 fee =  reward * processingFeeMagnitude / 1000;
        reward -= fee;
        processingFees += fee;

        user.totalValueClaimed += valueOfOutTokens(reward);

        // Stake 
        user.totalStakeAmount += reward;
        amountIn += reward;
        totalStaked += reward;
        updateDividendsBatch();
        
        emit AutoCompounded(userAddress, reward);
    }


    function doSetAutoCompoundEnabled(address userAddress, bool isEnabled) internal {
        require(isEnabled != isAutoCompoundEnabled(userAddress), "AutoCompoundPool: Value unchanged");

        if (isEnabled) {
            autoCompoundIndices[userAddress] = autoCompoundAddresses.length;
            autoCompoundAddresses.push(userAddress);
        } else {
            uint256 index = autoCompoundIndices[userAddress];
            address lastAddress = autoCompoundAddresses[autoCompoundAddresses.length - 1];

            autoCompoundIndices[lastAddress] = index;
            autoCompoundAddresses[index] = autoCompoundAddresses[autoCompoundAddresses.length - 1]; 
            autoCompoundAddresses.pop();

            delete autoCompoundIndices[userAddress];
        }
        
        emit AutoCompoundStatusChanged(userAddress, isEnabled);
    }

    function setAutoCompoundEnabled(bool isEnabled) external notUnauthorizedContract {
        doSetAutoCompoundEnabled(msg.sender, isEnabled);
    }

    function setAutoCompoundEnabled(address userAddress, bool isEnabled) external onlyAdmins {
        doSetAutoCompoundEnabled(userAddress, isEnabled);
    }

    function isAutoCompoundEnabled(address userAddress) public view returns(bool) {
        uint256 index = autoCompoundIndices[userAddress];
        return index < autoCompoundAddresses.length  && autoCompoundAddresses[index] == userAddress;
    }

    function setMinEarningsToAutoCompound(uint256 value) external onlyOwner {
        require(value > 0, "AutoCompoundPool: Invalid value");
        minEarningsToAutoCompound = value;
    }

    function setIsAutoCompoundAvailable(bool isAvailable) external onlyOwner {
        isAutoCompoundAvailable = isAvailable;
    }

    function setProcessingFeeMagnitude(uint256 magnitude) external onlyOwner {
        require(magnitude <= 1000, "AutoCompoundPool: Invalid value");
        processingFeeMagnitude = magnitude;
    }

    function autoCompoundAddressesLength() external view returns(uint256) {
        return autoCompoundAddresses.length;
    }
}