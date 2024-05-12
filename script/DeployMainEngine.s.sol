// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {MainEngine} from "../src/MainEngine.sol";

contract DeployMainEngine is Script {
    function run() public returns (MainEngine) {
        vm.startBroadcast(makeAddr("CREATOR"));
        MainEngine deployedContract = new MainEngine();
        vm.stopBroadcast();
        return deployedContract;
    }
}
