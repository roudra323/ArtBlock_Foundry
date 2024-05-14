// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { DeployMainEngine } from "../../script/DeployMainEngine.s.sol";
import { MainEngine } from "../../src/MainEngine.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import { CustomERC20Token } from "../../src/CustomERC20Token.sol";

contract MainEngineTest is Test {
    MainEngine mainEngine;
    CustomERC20Token artBlockToken;

    uint256 private immutable STARTING_BUYING_AMOUNT_ERC20 = 1000;
    uint256 private immutable TOTAL_AMOUNT_TO_PAY = 1000 wei * STARTING_BUYING_AMOUNT_ERC20;

    address private immutable creatorProtocol = makeAddr("CREATOR");
    address private immutable USER = makeAddr("USER");

    function setUp() public {
        DeployMainEngine deployMainEngine = new DeployMainEngine();
        mainEngine = deployMainEngine.run();
        address tokenAddress = mainEngine.getTokenAddress(); // Get the address
        artBlockToken = CustomERC20Token(tokenAddress); // Create a new ArtBlockToken instance
    }

    function testGetAdderssOfProtocolCreator() public view {
        address creator = mainEngine.getCreatorProtocol();
        console.log("Creator Protocol: ", creator);
        assertEq(mainEngine.getCreatorProtocol(), creatorProtocol);
    }

    function testBuyArtBlockToken() public {
        uint256 amount = STARTING_BUYING_AMOUNT_ERC20;
        uint256 tokenAmount = 1000 wei * amount; // 1 ArtBlock token = 1000 wei
        // Deal the required amount of Ether to the USER account
        vm.deal(USER, tokenAmount);
        // Call the buyArtBlockToken function with the required amount of Ether
        mainEngine.buyArtBlockToken{ value: tokenAmount }(USER, amount);
        // Add assertions to verify the expected behavior
        assertEq(artBlockToken.balanceOf(USER), amount, "Incorrect token balance");
    }

    modifier buyArtBlockToken() {
        vm.deal(USER, TOTAL_AMOUNT_TO_PAY);
        mainEngine.buyArtBlockToken{ value: TOTAL_AMOUNT_TO_PAY }(USER, STARTING_BUYING_AMOUNT_ERC20);
        _;
    }

    function testCreatorBalanceAfterTokenSold() public buyArtBlockToken {
        assertEq(address(creatorProtocol).balance, TOTAL_AMOUNT_TO_PAY, "Incorrect balance");
    }
}
