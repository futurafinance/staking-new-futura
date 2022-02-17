// SPDX-License-Identifier: MIT

pragma solidity ^0.8.5;

import "./../interfaces/IBEP20.sol";

interface IFutura is IBEP20 {
    function processRewardClaimQueue(uint256 gas) external;

    function calculateRewardCycleExtension(uint256 balance, uint256 amount) external view returns (uint256);

    function claimReward() external;

    function claimReward(address addr) external;

    function isRewardReady(address user) external view returns (bool);

    function isExcludedFromFees(address addr) external view returns(bool);

    function increaseAllowance(address spender, uint256 addedValue) external returns (bool);

    function rewardClaimQueueIndex() external view returns(uint256);

    function setFirstToken(string memory token) external;

    function setSecondToken(string memory token) external;

    function setClaimDivision(uint8 claimDivision) external;

    function getFirstToken(address user) external view returns (address);

    function getSecondToken(address user) external view returns (address);

    function isTokenAllowed(string memory symbol) external view returns (bool);

    function getTokenAddress(string memory symbol) external;
}