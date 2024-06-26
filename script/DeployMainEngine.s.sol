// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { MainEngine } from "../src/MainEngine.sol";

contract DeployMainEngine is Script {
    function run() public returns (MainEngine deployedContract) {
        vm.startBroadcast(makeAddr("CREATOR"));
        deployedContract = new MainEngine();
        vm.stopBroadcast();
    }
}
