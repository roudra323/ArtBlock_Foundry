// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { DeployMainEngine } from "../../script/DeployMainEngine.s.sol";
import { MainEngine } from "../../src/MainEngine.sol";
import { VotingContract } from "../../src/ARTBlockVoting.sol";
import { CustomERC20Token } from "../../src/CustomERC20Token.sol";

contract VotingTest is Test {
    event VoteCasted(bytes4 indexed productId, address indexed communityToken, bool indexed isUPVote);

    MainEngine mainEngine;
    VotingContract votingContract;
    CustomERC20Token artBlockToken;

    uint256 private PRECESSION = 10 ** 18;
    uint256 private immutable TOKEN_AMOUNT = 200_000;

    address private immutable COMMUNITY_CREATOR = makeAddr("COMMUNITY_CREATOR");
    address private immutable USER = makeAddr("USER");
    address private immutable USER_2 = makeAddr("USER_2");

    function setUp() public {
        DeployMainEngine deployMainEngine = new DeployMainEngine();
        (mainEngine, votingContract) = deployMainEngine.run();
        address tokenAddress = mainEngine.getTokenAddress();
        artBlockToken = CustomERC20Token(tokenAddress);
    }

    function buyArtBlockToken(address toAccount, uint256 tokenAmount) public {
        vm.startPrank(toAccount);
        artBlockToken.approve(address(mainEngine), tokenAmount * PRECESSION);
        vm.stopPrank();
        uint256 tokenRate = mainEngine.getArtBlockRate();
        uint256 amountToPay = tokenRate * tokenAmount;
        vm.deal(toAccount, amountToPay);
        console.log(
            "ArtBlock Token Balance(Before): ", CustomERC20Token(artBlockToken).balanceOf(toAccount) / PRECESSION
        );
        mainEngine.buyArtBlockToken{ value: amountToPay }(toAccount, tokenAmount);
        console.log(
            "ArtBlock Token Balance(after): ", CustomERC20Token(artBlockToken).balanceOf(toAccount) / PRECESSION
        );
    }

    function createCommunity(address creator) public {
        string memory communityName = "ART Community";
        string memory communityDescription = "People can sell their art here";
        string memory tokenName = "PeopleArtToken";
        string memory tokenSymbol = "PAT";

        uint256 tokenRate = mainEngine.getArtBlockRate();
        uint256 amountToPay = tokenRate * TOKEN_AMOUNT;

        vm.startPrank(creator);
        artBlockToken.approve(address(mainEngine), amountToPay);
        vm.stopPrank();
        mainEngine.createCommunity(communityName, communityDescription, tokenName, tokenSymbol, creator);
    }

    function joinCommunity(address user, address communityTokenAddress) public {
        vm.prank(user);
        mainEngine.joinCommunity(communityTokenAddress);
    }

    function buyCommunityToken(address toAccount, uint256 amount, address communityTokenAddress) public {
        uint256 communityTokenCost = mainEngine.getCommunityTokenCost(toAccount, amount, communityTokenAddress);
        buyArtBlockToken(toAccount, communityTokenCost);
        // mainEngine.buyArtBlockToken{ value: communityTokenCost }(toAccount, communityTokenCost);
        mainEngine.buyCommunityToken(toAccount, amount, communityTokenAddress);
        console.log(
            "Community Token Balance: ", CustomERC20Token(communityTokenAddress).balanceOf(toAccount) / PRECESSION
        );
        console.log("ArtBlock Token Balance: ", CustomERC20Token(artBlockToken).balanceOf(toAccount) / PRECESSION);
    }

    function submitProductToCommunity(address creator, address communityTokenAddress) public {
        uint256 productPrice = 1000;
        string memory metaData = "https://www.artwork.com Artwork A beautiful piece of art";
        bool isExclusive = true;
        buyCommunityToken(creator, productPrice, communityTokenAddress);
        vm.startPrank(creator);
        CustomERC20Token(communityTokenAddress).approve(address(mainEngine), productPrice * PRECESSION);
        mainEngine.submitNewProduct(metaData, communityTokenAddress, productPrice, isExclusive);
        vm.stopPrank();
    }

    // Add your voting-related tests below
    function testVoting() public {
        // Setup
        buyArtBlockToken(COMMUNITY_CREATOR, TOKEN_AMOUNT);
        createCommunity(COMMUNITY_CREATOR);
        address communityTokenAddress = mainEngine.communityTokens(0);

        // Join community
        joinCommunity(USER, communityTokenAddress);
        joinCommunity(USER_2, communityTokenAddress);

        // Submit product
        submitProductToCommunity(COMMUNITY_CREATOR, communityTokenAddress);
        // bytes4 userProductID = mainEngine.userProducts(COMMUNITY_CREATOR, communityTokenAddress, 0);
        // console.log(userProductID);
        // TODO: Implement voting tests
        // Example:
        // - Test casting a vote
        // - Test voting period
        // - Test vote counting
        // - Test voting results
    }

    // Add your voting-related tests below
    function testUpVotingForAProduct() public {
        // Setup
        buyArtBlockToken(COMMUNITY_CREATOR, TOKEN_AMOUNT);
        createCommunity(COMMUNITY_CREATOR);
        address communityTokenAddress = mainEngine.communityTokens(0);

        // Join community
        joinCommunity(USER, communityTokenAddress);
        joinCommunity(USER_2, communityTokenAddress);

        // Submit product
        submitProductToCommunity(COMMUNITY_CREATOR, communityTokenAddress);
        bytes4 userProductID = mainEngine.userProducts(COMMUNITY_CREATOR, communityTokenAddress, 0);

        mainEngine.getProductBaseInfo(userProductID);

        // Expect the event to be emitted
        vm.expectEmit(true, true, true, true);
        emit VoteCasted(userProductID, communityTokenAddress, true);

        // Perform the action that should emit the event
        vm.prank(USER); // Assuming USER is the one voting
        votingContract.voteForProduct(userProductID, communityTokenAddress, true);
    }

    modifier tillSubmitProduct() {
        // Initial setup
        uint256 createCommunityTokenAmount = mainEngine.getCommunityCreationFee();
        buyArtBlockToken(COMMUNITY_CREATOR, createCommunityTokenAmount);
        createCommunity(COMMUNITY_CREATOR);
        address communityTokenAddress = mainEngine.communityTokens(0);
        // Submit product
        submitProductToCommunity(COMMUNITY_CREATOR, communityTokenAddress);
        _;
    }

    function testMultipleUpVotingForAProduct(uint32 token) public tillSubmitProduct {
        // community token address
        address communityTokenAddress = mainEngine.communityTokens(0);
        bytes4 userProductID = mainEngine.userProducts(COMMUNITY_CREATOR, communityTokenAddress, 0);
        uint256 tokenToMint = token;
        uint256 totalVotingWeight = 0;
        // join community
        for (uint256 i = 1; i <= 5; i++) {
            address user = address(uint160(i));

            vm.startPrank(user);
            mainEngine.joinCommunity(communityTokenAddress);
            vm.stopPrank();

            buyArtBlockToken(user, tokenToMint * i);
            buyCommunityToken(user, tokenToMint * (7 - i), communityTokenAddress);

            uint256 userCommunitytoken = CustomERC20Token(communityTokenAddress).balanceOf(user);
            uint256 userArtBlockToken = CustomERC20Token(artBlockToken).balanceOf(user);

            console.log("CommunityToken: ", userCommunitytoken / 1e8, "ArtBlockToken: ", userArtBlockToken / 1e8);

            vm.startPrank(user);
            votingContract.voteForProduct(userProductID, communityTokenAddress, true);
            totalVotingWeight += votingContract.getVotingWeight(user, communityTokenAddress);
            vm.stopPrank();
            // Advance the block to ensure pranks don't overlap
            vm.roll(block.number + 1);
        }
        uint256 upvote = votingContract.getProductVotingInfo(userProductID).upvotes;
        uint256 downvotes = votingContract.getProductVotingInfo(userProductID).downvotes;
        assertEq(upvote, totalVotingWeight);
        assertEq(downvotes, 0);
    }

    function testSingleUpVoting(uint32 token) public tillSubmitProduct {
        // community token address
        address communityTokenAddress = mainEngine.communityTokens(0);
        bytes4 userProductID = mainEngine.userProducts(COMMUNITY_CREATOR, communityTokenAddress, 0);
        vm.assume(token < 50);
        uint256 tokenToMint = token;
        // join community
        uint256 i = 1;
        address user = address(uint160(i));

        vm.prank(user);
        mainEngine.joinCommunity(communityTokenAddress);

        buyArtBlockToken(user, tokenToMint * i);
        buyCommunityToken(user, tokenToMint * (7 - i), communityTokenAddress);

        uint256 userCommunitytoken = CustomERC20Token(communityTokenAddress).balanceOf(user);
        uint256 userArtBlockToken = CustomERC20Token(artBlockToken).balanceOf(user);

        vm.startPrank(user);
        votingContract.voteForProduct(userProductID, communityTokenAddress, true);
        vm.stopPrank();
        // Advance the block to ensure pranks don't overlap
        vm.roll(block.number + 1);

        uint256 upvote = votingContract.getProductVotingInfo(userProductID).upvotes;
        uint256 downvotes = votingContract.getProductVotingInfo(userProductID).downvotes;
    }
}
