// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { MainEngine } from "../src/MainEngine.sol";
import { VotingContract } from "../src/ARTBlockVoting.sol";
import { ArtBlockNFT } from "../src/ArtBlockNFT.sol";

contract DeployMainEngine is Script {
    function run()
        public
        returns (MainEngine deployedContract, VotingContract deployedVotingContract, ArtBlockNFT deployedNFTContract)
    {
        vm.startBroadcast(makeAddr("CREATOR"));
        deployedContract = new MainEngine();
        deployedVotingContract = new VotingContract(address(deployedContract));
        deployedContract.setVotingContract(address(deployedVotingContract));
        deployedNFTContract = new ArtBlockNFT(address(deployedContract));
        deployedContract.setNFTContract(address(deployedNFTContract));
        vm.stopBroadcast();
    }
}
