// SPDX-License-Identifier: MIT
pragma solidity ^0.8.5;

interface IMasterChef {
    function enterStaking(uint256 amount) external;

    function leaveStaking(uint256 amount) external;

    function pendingCake(uint256 _pid, address _user) external view returns (uint256);
}