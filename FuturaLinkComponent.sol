// SPDX-License-Identifier: MIT

pragma solidity >= 0.8.5;

import "./interfaces/IFutura.sol";
import "./interfaces/IFuturaLinkFuel.sol";
import "./interfaces/IFuturaLink.sol";
import "./interfaces/IFuturaLinkPool.sol";
import "./interfaces/IPancakePair.sol";
import "./interfaces/IPancakeRouterV2.sol";
import "./utils/EmergencyWithdrawable.sol";

contract FuturaLinkComponent is AccessControlled, EmergencyWithdrawable {
    IFutura public futura;
    IFuturaLinkFuel public fuel;
    uint256 public processGas = 300000;

    modifier process() {
        if (processGas > 0) {
            fuel.addGas(processGas);
        }
        
        _;
    }

    constructor(IFutura _futura, IFuturaLinkFuel _fuel) {
        require(address(_futura) != address(0), "FuturaLinkComponent: Invalid address");
       
        futura = _futura;
        fuel = _fuel;
    }

    function setProcessGas(uint256 gas) external onlyOwner {
        processGas = gas;
    }

    function setFutura(IFutura _futura) public onlyOwner {
        require (address(_futura) != address(0), "FuturaLinkComponent: Invalid address");
        futura = _futura;
    }
    
    function setFuel(IFuturaLinkFuel _fuel) public onlyOwner {
        require (address(_fuel) != address(0), "FuturaLinkComponent: Invalid address");
        fuel = _fuel;
    }
}