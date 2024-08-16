// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { VotingContract } from "../src/ARTBlockVoting.sol";

contract DeployMainEngine is Script {
    function run() public {
        vm.startBroadcast(makeAddr("CREATOR"));
        // deployedContract = new MainEngine();
        // deployedVotingContract = new VotingContract(address(deployedContract));
        vm.stopBroadcast();
    }
}
