// SPDX-License-Identifier: MIT

pragma solidity ^0.8.5;

interface IFuturaLinkPool {
    function outTokenAddress() external view returns (address);

    function inTokenAddress() external view returns (address);

    function isStakingEnabled() external view returns(bool);

    function earlyUnstakingFeeDuration() external view returns(uint256);

    function unstakingFeeMagnitude() external view returns(uint16);

    function unclaimedValueOf(address userAddress) external view returns (uint256);

    function totalValueClaimed(address userAddress) external view returns(uint256);

    function deposit(uint256 amount, uint256 gas) external payable;

}