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

    uint256 private baseRate = 0.5 ether;
    uint256 pricePerToken = baseRate * 1;

    uint256 private PRECESSION = 10 ** 18;
    uint256 private immutable STARTING_BUYING_AMOUNT_ERC20 = 200_000;
    uint256 private TOTAL_AMOUNT_TO_PAY = pricePerToken * STARTING_BUYING_AMOUNT_ERC20;

    // uint256 totalCost = pricePerToken * STARTING_BUYING_AMOUNT_ERC20;

    address private immutable creatorProtocol = makeAddr("CREATOR");
    address private immutable USER = makeAddr("USER");
    address private immutable COMMUNITY_CREATOR = makeAddr("COMMUNITY_CREATOR");
    address private immutable USER_2 = makeAddr("USER_2");
    address private immutable USER_3 = makeAddr("USER_3");

    event CommunityCreated(string communityName, address communityCreator, address communityToken);

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

    ///////////////////////////
    // Test buyArtBlockToken //
    ///////////////////////////

    function testBuyArtBlockToken() public {
        uint256 amount = STARTING_BUYING_AMOUNT_ERC20;
        uint256 tokenAmount = TOTAL_AMOUNT_TO_PAY; // 1 ArtBlock token = 1000 wei

        console.log("Total Supply: ", artBlockToken.totalSupply());
        // Deal the required amount of Ether to the USER account
        vm.deal(USER, tokenAmount);
        // Call the buyArtBlockToken function with the required amount of Ether
        mainEngine.buyArtBlockToken{ value: tokenAmount }(USER, amount);
        // Add assertions to verify the expected behavior
        assertEq(artBlockToken.balanceOf(USER), amount * PRECESSION, "Incorrect token balance");
    }

    modifier buyArtBlockToken(address toAccount) {
        vm.deal(toAccount, TOTAL_AMOUNT_TO_PAY);
        mainEngine.buyArtBlockToken{ value: TOTAL_AMOUNT_TO_PAY }(toAccount, STARTING_BUYING_AMOUNT_ERC20);
        _;
    }

    function buyArtBlockTokenUSER(address toAccount, uint256 tokenAmount) public {
        uint256 tokenRate = mainEngine.getArtBlockRate();
        uint256 amountToPay = tokenRate * tokenAmount;
        // console.log("Token Rate: (Test)", tokenRate);
        // console.log("Total Cost: (Test)", amountToPay);
        vm.deal(toAccount, amountToPay);
        mainEngine.buyArtBlockToken{ value: amountToPay }(toAccount, tokenAmount);
    }

    function testCreatorBalanceAfterTokenSold() public buyArtBlockToken(USER) {
        assertEq(address(creatorProtocol).balance, TOTAL_AMOUNT_TO_PAY, "Incorrect balance");
    }

    /////////////////////////////
    // Test Create Community  ///
    /////////////////////////////

    modifier startsPrank(address PrankAccount) {
        vm.startPrank(PrankAccount);
        _;
        vm.stopPrank();
    }

    function testCreateCommunity() public buyArtBlockToken(COMMUNITY_CREATOR) startsPrank(COMMUNITY_CREATOR) {
        string memory communityName = "ART Community";
        string memory communityDescription = "People can sell their art here";
        string memory tokenName = "PeopleArtToken";
        string memory tokenSymbol = "PAT";

        // Approving Main Engine contract
        artBlockToken.approve(address(mainEngine), TOTAL_AMOUNT_TO_PAY);

        mainEngine.createCommunity(communityName, communityDescription, tokenName, tokenSymbol, COMMUNITY_CREATOR);
        // address communityTokenAddress = mainEngine.communityTokens(0);
        (string memory name,,,,,) = mainEngine.creatorCommunities(COMMUNITY_CREATOR, 0);
        assertEq(name, communityName);
    }

    function testCreateCommunityWithInsufficientBalance() public startsPrank(USER) {
        string memory communityName = "ART Community";
        string memory communityDescription = "People can sell their art here";
        string memory tokenName = "PeopleArtToken";
        string memory tokenSymbol = "PAT";

        vm.expectRevert(MainEngine.MainEngine__InSufficientAmount.selector);
        mainEngine.createCommunity(communityName, communityDescription, tokenName, tokenSymbol, USER);
    }

    modifier createCommunity() {
        vm.startPrank(COMMUNITY_CREATOR);
        string memory communityName = "ART Community";
        string memory communityDescription = "People can sell their art here";
        string memory tokenName = "PeopleArtToken";
        string memory tokenSymbol = "PAT";
        artBlockToken.approve(address(mainEngine), TOTAL_AMOUNT_TO_PAY);
        mainEngine.createCommunity(communityName, communityDescription, tokenName, tokenSymbol, COMMUNITY_CREATOR);
        vm.stopPrank();
        _;
    }

    ///////////////////////////////
    //// Test Join Community //////
    ///////////////////////////////

    function testJoinCommunity() public buyArtBlockToken(COMMUNITY_CREATOR) createCommunity {
        address communityTokenAddress = mainEngine.communityTokens(0);
        vm.prank(USER_2);
        mainEngine.joinCommunity(communityTokenAddress);
        assertEq(mainEngine.isCommunityMember(USER_2, communityTokenAddress), true);
    }

    function testJoinMultipleUsersToCommunity() public buyArtBlockToken(COMMUNITY_CREATOR) createCommunity {
        address communityTokenAddress = mainEngine.communityTokens(0);
        for (uint256 i = 1; i <= 5; i++) {
            address user = address(uint160(i));
            vm.prank(user);
            mainEngine.joinCommunity(communityTokenAddress);
            assertEq(mainEngine.isCommunityMember(user, mainEngine.communityTokens(0)), true);
        }
    }

    function testMemberReturnesTrueIfJoinedCommunity() public buyArtBlockToken(COMMUNITY_CREATOR) createCommunity {
        address communityTokenAddress = mainEngine.communityTokens(0);
        vm.prank(USER_3);
        mainEngine.joinCommunity(communityTokenAddress);
        assertEq(mainEngine.isCommunityMember(USER_3, communityTokenAddress), true);
    }

    function testFailToJoinCommunityIfAlreadyMember() public buyArtBlockToken(COMMUNITY_CREATOR) createCommunity {
        address communityTokenAddress = mainEngine.communityTokens(0);
        vm.startPrank(USER_2);
        mainEngine.joinCommunity(communityTokenAddress);
        mainEngine.joinCommunity(communityTokenAddress);
        vm.expectRevert(MainEngine.MainEngine__AlreadyAMember.selector);
        vm.stopPrank();
    }

    ///////////////////////////////////////////
    ///////// Test Buy Community Token ////////
    ///////////////////////////////////////////

    function testBuyCommunityToken() public buyArtBlockToken(COMMUNITY_CREATOR) createCommunity startsPrank(USER_2) {
        buyArtBlockTokenUSER(USER_2, STARTING_BUYING_AMOUNT_ERC20);
        address communityTokenAddress = mainEngine.communityTokens(0);
        uint256 amount = 2000;
        mainEngine.buyCommunityToken(USER_2, amount, communityTokenAddress);
        assertEq(CustomERC20Token(communityTokenAddress).balanceOf(USER_2), amount * PRECESSION);
    }

    function buyCommunityTokenUSER(address toAccount, uint256 amount, address communityTokenAddress) public {
        buyArtBlockTokenUSER(toAccount, amount);
        mainEngine.buyCommunityToken(toAccount, amount, communityTokenAddress);
    }

    //////////////////////////////////////
    ///////// Test Submit Product ////////
    //////////////////////////////////////

    function testSubmitProductToCommunity(uint256 product_price)
        public
        buyArtBlockToken(COMMUNITY_CREATOR)
        createCommunity
        startsPrank(COMMUNITY_CREATOR)
    {
        address communityTokenAddress = mainEngine.communityTokens(0);
        buyCommunityTokenUSER(COMMUNITY_CREATOR, product_price, communityTokenAddress);

        uint256 productPrice = product_price;
        string memory metaData = "https://www.artwork.com Artwork A beautiful piece of art";
        bool isExlcusive = true;
        console.log(
            "Community Creator Balance of Community token: ",
            CustomERC20Token(communityTokenAddress).balanceOf(COMMUNITY_CREATOR)
        );
        CustomERC20Token(communityTokenAddress).approve(address(mainEngine), productPrice * PRECESSION);
        mainEngine.submitNewProduct(metaData, communityTokenAddress, productPrice, isExlcusive);
    }
}
