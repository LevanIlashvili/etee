// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {ETEEPay} from "../src/ETEEPay.sol";
import {MockUSDC} from "../src/MockUSDC.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPk = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPk);
        address treasury = vm.envOr("TREASURY_ADDRESS", deployer);
        uint16 feeBps = uint16(vm.envOr("FEE_BPS", uint256(500)));

        vm.startBroadcast(deployerPk);

        MockUSDC usdc = new MockUSDC();
        ETEEPay pay = new ETEEPay(IERC20(address(usdc)), treasury, feeBps, deployer);

        usdc.mint(deployer, 1_000_000e6);

        vm.stopBroadcast();

        console2.log("MockUSDC:", address(usdc));
        console2.log("ETEEPay: ", address(pay));
        console2.log("Treasury:", treasury);
        console2.log("Owner:   ", deployer);
        console2.log("Fee bps: ", feeBps);
    }
}
