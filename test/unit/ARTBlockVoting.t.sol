// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { DeployMainEngine } from "../../script/DeployMainEngine.s.sol";
import { MainEngine } from "../../src/MainEngine.sol";
import { VotingContract } from "../../src/ARTBlockVoting.sol";
import { CustomERC20Token } from "../../src/CustomERC20Token.sol";
import { ArtBlockNFT } from "../../src/ArtBlockNFT.sol";

contract VotingTest is Test {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    error VotingContract__VotingOnGoing(bytes4 productId);

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event VoteCasted(bytes4 indexed productId, address indexed communityToken, bool indexed isUPVote);

    MainEngine mainEngine;
    VotingContract votingContract;
    CustomERC20Token artBlockToken;
    ArtBlockNFT artBlockNFT;

    uint256 private PRECESSION = 10 ** 18;
    uint256 private immutable TOKEN_AMOUNT = 200_000;
    address private DEPLOYER = makeAddr("CREATOR");
    address private immutable COMMUNITY_CREATOR = makeAddr("COMMUNITY_CREATOR");
    address private immutable USER = makeAddr("USER");
    address private immutable USER_2 = makeAddr("USER_2");

    function setUp() public {
        DeployMainEngine deployMainEngine = new DeployMainEngine();
        (mainEngine, votingContract, artBlockNFT) = deployMainEngine.run();
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
        mainEngine.buyArtBlockToken{ value: amountToPay }(toAccount, tokenAmount);
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

    function testMultipleUpVotingForAProduct(uint32 token, bool _upVoteORdownVote) public tillSubmitProduct {
        // community token address
        address communityTokenAddress = mainEngine.communityTokens(0);
        bytes4 userProductID = mainEngine.userProducts(COMMUNITY_CREATOR, communityTokenAddress, 0);
        uint256 tokenToMint = token;
        bool upVoteORdownVote = _upVoteORdownVote;
        uint256 totalUpvote;
        uint256 totalDownvote;
        // join community
        for (uint256 i = 1; i <= 5; i++) {
            address user = address(uint160(i));

            vm.startPrank(user);
            mainEngine.joinCommunity(communityTokenAddress);
            vm.stopPrank();

            buyArtBlockToken(user, tokenToMint * i);
            buyCommunityToken(user, tokenToMint * (7 - i), communityTokenAddress);

            vm.startPrank(user);
            votingContract.voteForProduct(userProductID, communityTokenAddress, upVoteORdownVote);
            uint256 totalVotingWeight = votingContract.getVotingWeight(user, communityTokenAddress);
            if (upVoteORdownVote) {
                totalUpvote += totalVotingWeight;
            } else {
                totalDownvote += totalVotingWeight;
            }
            vm.stopPrank();
            // Advance the block to ensure pranks don't overlap
            vm.roll(block.number + 1);
        }
        uint256 upvote = votingContract.getProductVotingInfo(userProductID).upvotes;
        uint256 downvotes = votingContract.getProductVotingInfo(userProductID).downvotes;

        // Checks
        assertEq(upvote, totalUpvote);
        assertEq(downvotes, totalDownvote);
    }

    function test_Reverts_When_Voting_On_Going() public tillSubmitProduct {
        // community token address
        address communityTokenAddress = mainEngine.communityTokens(0);
        bytes4 userProductID = mainEngine.userProducts(COMMUNITY_CREATOR, communityTokenAddress, 0);
        uint256 tokenToMint = 1000;
        bool upVoteORdownVote = true;

        // join community
        for (uint256 i = 1; i <= 5; i++) {
            address user = address(uint160(i));

            vm.startPrank(user);
            mainEngine.joinCommunity(communityTokenAddress);
            vm.stopPrank();

            buyArtBlockToken(user, tokenToMint * i);
            buyCommunityToken(user, tokenToMint * (7 - i), communityTokenAddress);

            vm.startPrank(user);
            votingContract.voteForProduct(userProductID, communityTokenAddress, upVoteORdownVote);
            vm.stopPrank();
            // Advance the block to ensure pranks don't overlap
            vm.roll(block.number + 1);
        }
        vm.expectRevert(abi.encodeWithSelector(VotingContract__VotingOnGoing.selector, userProductID));

        vm.prank(address(mainEngine));
        votingContract.calculateVotingResult(userProductID);
    }

    function test_Approve_Product_if_Upvotes_are_greater() public tillSubmitProduct {
        // community token address
        address communityTokenAddress = mainEngine.communityTokens(0);
        bytes4 userProductID = mainEngine.userProducts(COMMUNITY_CREATOR, communityTokenAddress, 0);
        uint256 productSubmittedTime = mainEngine.getProductBaseInfo(userProductID).productSubmittedTime;
        uint256 tokenToMint = 1000;
        bool upVoteORdownVote = true;

        // join community
        for (uint256 i = 1; i <= 5; i++) {
            address user = address(uint160(i));

            vm.startPrank(user);
            mainEngine.joinCommunity(communityTokenAddress);
            vm.stopPrank();

            buyArtBlockToken(user, tokenToMint * i);
            buyCommunityToken(user, tokenToMint * (7 - i), communityTokenAddress);

            vm.startPrank(user);
            votingContract.voteForProduct(userProductID, communityTokenAddress, upVoteORdownVote);
            vm.stopPrank();
            // Advance the block to ensure pranks don't overlap
            vm.roll(block.number + 1);
        }
        vm.warp(productSubmittedTime + 8 days);
        // vm.expectRevert(abi.encodeWithSelector(VotingContract__VotingOnGoing.selector, userProductID));

        vm.prank(address(mainEngine));
        votingContract.calculateVotingResult(userProductID);
        assertEq(votingContract.getProductVotingInfo(userProductID).approved, true);
    }

    function test_check_product_approval_from_mainContract() public tillSubmitProduct {
        address communityTokenAddress = mainEngine.communityTokens(0);
        bytes4 userProductID = mainEngine.userProducts(COMMUNITY_CREATOR, communityTokenAddress, 0);
        bool isApproved = mainEngine.checkProductApprovalStatus(userProductID);
        assertFalse(isApproved);
    }

    function test_returns_true_from_mainContract() public tillSubmitProduct {
        address communityTokenAddress = mainEngine.communityTokens(0);
        bytes4 userProductID = mainEngine.userProducts(COMMUNITY_CREATOR, communityTokenAddress, 0);
        uint256 productSubmittedTime = mainEngine.getProductBaseInfo(userProductID).productSubmittedTime;
        uint256 tokenToMint = 1000;
        bool upVoteORdownVote = true;

        // join community
        for (uint256 i = 1; i <= 5; i++) {
            address user = address(uint160(i));

            vm.startPrank(user);
            mainEngine.joinCommunity(communityTokenAddress);
            vm.stopPrank();

            buyArtBlockToken(user, tokenToMint * i);
            buyCommunityToken(user, tokenToMint * (7 - i), communityTokenAddress);

            vm.startPrank(user);
            votingContract.voteForProduct(userProductID, communityTokenAddress, upVoteORdownVote);
            vm.stopPrank();
            // Advance the block to ensure pranks don't overlap
            vm.roll(block.number + 1);
        }
        vm.warp(productSubmittedTime + 8 days);
        // vm.expectRevert(abi.encodeWithSelector(VotingContract__VotingOnGoing.selector, userProductID));

        vm.prank(address(mainEngine));
        votingContract.calculateVotingResult(userProductID);
        assertEq(votingContract.getProductVotingInfo(userProductID).approved, true);

        bool isApproved = mainEngine.checkProductApprovalStatus(userProductID);
        assertTrue(isApproved);
    }

    function test_returns_false_from_mainContract() public tillSubmitProduct {
        address communityTokenAddress = mainEngine.communityTokens(0);
        bytes4 userProductID = mainEngine.userProducts(COMMUNITY_CREATOR, communityTokenAddress, 0);
        uint256 productSubmittedTime = mainEngine.getProductBaseInfo(userProductID).productSubmittedTime;
        uint256 tokenToMint = 1000;
        bool upVoteORdownVote = false;

        // join community
        for (uint256 i = 1; i <= 5; i++) {
            address user = address(uint160(i));

            vm.startPrank(user);
            mainEngine.joinCommunity(communityTokenAddress);
            vm.stopPrank();

            buyArtBlockToken(user, tokenToMint * i);
            buyCommunityToken(user, tokenToMint * (7 - i), communityTokenAddress);

            vm.startPrank(user);
            votingContract.voteForProduct(userProductID, communityTokenAddress, upVoteORdownVote);
            vm.stopPrank();
            // Advance the block to ensure pranks don't overlap
            vm.roll(block.number + 1);
        }
        vm.warp(productSubmittedTime + 8 days);

        vm.prank(address(mainEngine));
        votingContract.calculateVotingResult(userProductID);
        assertEq(votingContract.getProductVotingInfo(userProductID).approved, false);

        bool isApproved = mainEngine.checkProductApprovalStatus(userProductID);
        assertFalse(isApproved);
    }

    function submitsProductAndcalculatesVotingResult(bool _upVoteORdownVote) public tillSubmitProduct {
        address communityTokenAddress = mainEngine.communityTokens(0);
        bytes4 userProductID = mainEngine.userProducts(COMMUNITY_CREATOR, communityTokenAddress, 0);
        uint256 productSubmittedTime = mainEngine.getProductBaseInfo(userProductID).productSubmittedTime;
        uint256 tokenToMint = 1000;
        bool upVoteORdownVote = _upVoteORdownVote;

        // join community
        for (uint256 i = 1; i <= 5; i++) {
            address user = address(uint160(i));

            vm.startPrank(user);
            mainEngine.joinCommunity(communityTokenAddress);
            vm.stopPrank();

            buyArtBlockToken(user, tokenToMint * i);
            buyCommunityToken(user, tokenToMint * (7 - i), communityTokenAddress);

            vm.startPrank(user);
            votingContract.voteForProduct(userProductID, communityTokenAddress, upVoteORdownVote);
            vm.stopPrank();
            // Advance the block to ensure pranks don't overlap
            vm.roll(block.number + 1);
        }
        vm.warp(productSubmittedTime + 8 days);
        // vm.expectRevert(abi.encodeWithSelector(VotingContract__VotingOnGoing.selector, userProductID));

        vm.prank(address(mainEngine));
        votingContract.calculateVotingResult(userProductID);
    }

    function test_product_is_approved_and_returns_full_stacked_amount() public tillSubmitProduct {
        address communityTokenAddress = mainEngine.communityTokens(0);
        bytes4 userProductID = mainEngine.userProducts(COMMUNITY_CREATOR, communityTokenAddress, 0);
        uint256 productSubmittedTime = mainEngine.getProductBaseInfo(userProductID).productSubmittedTime;
        uint256 tokenToMint = 1000;
        bool upVoteORdownVote = true;

        // join community
        for (uint256 i = 1; i <= 5; i++) {
            address user = address(uint160(i));

            vm.startPrank(user);
            mainEngine.joinCommunity(communityTokenAddress);
            vm.stopPrank();

            buyArtBlockToken(user, tokenToMint * i);
            buyCommunityToken(user, tokenToMint * (7 - i), communityTokenAddress);

            vm.startPrank(user);
            votingContract.voteForProduct(userProductID, communityTokenAddress, upVoteORdownVote);
            vm.stopPrank();
            // Advance the block to ensure pranks don't overlap
            vm.roll(block.number + 1);
        }
        vm.warp(productSubmittedTime + 8 days);
        // vm.expectRevert(abi.encodeWithSelector(VotingContract__VotingOnGoing.selector, userProductID));

        uint256 customTokenBalance = CustomERC20Token(communityTokenAddress).balanceOf(address(mainEngine));
        vm.prank(address(mainEngine));
        votingContract.calculateVotingResult(userProductID);
        // return the full stacked amount
        mainEngine.returnStackedAmount(userProductID);
        uint256 currentCustomTokenBalance = CustomERC20Token(communityTokenAddress).balanceOf(address(mainEngine));
        assertTrue(mainEngine.getProductBaseInfo(userProductID).stackReturned);
        assertEq(
            currentCustomTokenBalance, customTokenBalance - (mainEngine.getProductBaseInfo(userProductID).stakeAmount)
        );
    }

    function test_product_is_not_Approved_and_returns_half_stacked_amount() public tillSubmitProduct {
        address communityTokenAddress = mainEngine.communityTokens(0);
        bytes4 userProductID = mainEngine.userProducts(COMMUNITY_CREATOR, communityTokenAddress, 0);
        uint256 productSubmittedTime = mainEngine.getProductBaseInfo(userProductID).productSubmittedTime;
        uint256 tokenToMint = 1000;
        bool upVoteORdownVote = false;

        // join community
        for (uint256 i = 1; i <= 5; i++) {
            address user = address(uint160(i));

            vm.startPrank(user);
            mainEngine.joinCommunity(communityTokenAddress);
            vm.stopPrank();

            buyArtBlockToken(user, tokenToMint * i);
            buyCommunityToken(user, tokenToMint * (7 - i), communityTokenAddress);

            vm.startPrank(user);
            votingContract.voteForProduct(userProductID, communityTokenAddress, upVoteORdownVote);
            vm.stopPrank();
            // Advance the block to ensure pranks don't overlap
            vm.roll(block.number + 1);
        }
        vm.warp(productSubmittedTime + 8 days);
        vm.prank(address(mainEngine));
        votingContract.calculateVotingResult(userProductID);
        // return the full stacked amount
        mainEngine.returnStackedAmount(userProductID);
        uint256 currentCustomTokenBalance = CustomERC20Token(communityTokenAddress).balanceOf(address(mainEngine));
        assertTrue(mainEngine.getProductBaseInfo(userProductID).stackReturned);
        assertEq(currentCustomTokenBalance, mainEngine.getProductBaseInfo(userProductID).stakeAmount / 2);
    }
}
