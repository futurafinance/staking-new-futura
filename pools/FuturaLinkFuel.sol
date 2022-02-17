// SPDX-License-Identifier: MIT

pragma solidity >= 0.8.5;

import "./../interfaces/IFutura.sol";
import "./../interfaces/IFuturaLinkFuel.sol";
import "./../utils/AccessControlled.sol";
import "./../utils/EmergencyWithdrawable.sol";

contract FuturaLinkFuel is IFuturaLinkFuel, AccessControlled, EmergencyWithdrawable {
    IFutura public futura;

    uint256 minFundsBeforeProcessing = 100000000000000000 wei;
    uint256 processRewardQueueMaxGas = 0;

    event FuelRun();

    constructor(IFutura _futura) {
        setFutura(_futura);
    }

    receive() external payable { }

    function addGas(uint256 gas) external override notUnauthorizedContract {
        run(gas);
    }

    function buyGas(uint256 gas) external onlyAdmins {
        uint remainingGasStart = gasleft();

        run(gas);
        
        uint usedGas = remainingGasStart - gasleft() + 21000 + 9700;
        payable(tx.origin).transfer(usedGas * tx.gasprice);
    }

    function run(uint256 gas) internal {
        uint256 gasLeft = gasleft();

        if (processRewardQueueMaxGas > 0) {
            uint256 consumedGas = gasLeft - gasleft();
            if (consumedGas < gas) {
                gas = gas - consumedGas;
                if (gas > processRewardQueueMaxGas) {
                    gas = processRewardQueueMaxGas;
                }

                futura.processRewardClaimQueue(gas);
            }
        }

        emit FuelRun();
    }

    function setFutura(IFutura _futura) public onlyOwner {
        require(address(_futura) != address(0), "FuturaLinkFuel: Invalid address");
        futura = _futura;
    }

    function setMinFundsBeforeProcessing(uint256 amount) external onlyOwner {
        minFundsBeforeProcessing = amount;
    }

    function setProcessRewardQueueMaxGas(uint256 maxGas) external onlyOwner {
        processRewardQueueMaxGas = maxGas;
    }
}