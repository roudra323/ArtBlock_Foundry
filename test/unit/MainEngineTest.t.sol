// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { DeployMainEngine } from "../../script/DeployMainEngine.s.sol";
import { MainEngine } from "../../src/MainEngine.sol";
import { VotingContract } from "../../src/ARTBlockVoting.sol";
import { ERC20Mock } from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import { CustomERC20Token } from "../../src/CustomERC20Token.sol";
import { ArtBlockNFT } from "../../src/ArtBlockNFT.sol";

contract MainEngineTest is Test {
    MainEngine mainEngine;
    VotingContract votingContract;
    CustomERC20Token artBlockToken;
    ArtBlockNFT artBlockNFT;

    uint256 private PRECESSION = 10 ** 18;
    uint256 private immutable TOKEN_AMOUNT = 200_000;

    uint256 private COMMUNITY_TOKEN_INDEX = 0;

    address private immutable creatorProtocol = makeAddr("CREATOR");
    address private immutable USER = makeAddr("USER");
    address private immutable COMMUNITY_CREATOR = makeAddr("COMMUNITY_CREATOR");
    address private immutable USER_2 = makeAddr("USER_2");
    address private immutable USER_3 = makeAddr("USER_3");

    event CommunityCreated(string communityName, address communityCreator, address communityToken);

    function setUp() public {
        DeployMainEngine deployMainEngine = new DeployMainEngine();
        (mainEngine, votingContract, artBlockNFT) = deployMainEngine.run();
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

    function testBuyArtBlockToken(uint256 tokenAmount) public {
        if (tokenAmount <= 10_000_000_000 && tokenAmount > 0) {
            uint256 amount = tokenAmount;
            uint256 tokenRate = mainEngine.getArtBlockRate();
            uint256 amountToPay = tokenRate * amount;
            vm.deal(USER, amountToPay);
            mainEngine.buyArtBlockToken{ value: amountToPay }(USER, amount);
            assertEq(artBlockToken.balanceOf(USER), amount * PRECESSION, "Incorrect token balance");
        }
    }

    modifier buyArtBlockToken(address toAccount) {
        uint256 tokenRate = mainEngine.getArtBlockRate();
        uint256 amountToPay = tokenRate * TOKEN_AMOUNT;
        vm.deal(toAccount, amountToPay);
        mainEngine.buyArtBlockToken{ value: amountToPay }(toAccount, TOKEN_AMOUNT);
        _;
    }

    function buyArtBlockTokenUSER(address toAccount, uint256 tokenAmount) public {
        uint256 tokenRate = mainEngine.getArtBlockRate();
        uint256 amountToPay = tokenRate * tokenAmount;
        vm.deal(toAccount, amountToPay);
        mainEngine.buyArtBlockToken{ value: amountToPay }(toAccount, tokenAmount);
        artBlockToken.approve(address(mainEngine), tokenAmount * PRECESSION);
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

        uint256 tokenRate = mainEngine.getArtBlockRate();
        uint256 amountToPay = tokenRate * TOKEN_AMOUNT;

        // Approving Main Engine contract
        artBlockToken.approve(address(mainEngine), amountToPay);

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

        uint256 tokenRate = mainEngine.getArtBlockRate();
        uint256 amountToPay = tokenRate * TOKEN_AMOUNT;

        artBlockToken.approve(address(mainEngine), amountToPay);
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

    function testBuyCommunityToken() public buyArtBlockToken(COMMUNITY_CREATOR) createCommunity {
        buyArtBlockTokenUSER(USER_2, TOKEN_AMOUNT);
        address communityTokenAddress = mainEngine.communityTokens(0);
        uint256 amount = 2000;
        vm.prank(USER_2);
        artBlockToken.approve(address(mainEngine), amount * PRECESSION);
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
        if (product_price <= 1_000_000_000 && product_price > 0) {
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
            bytes4 userProductID = mainEngine.userProducts(COMMUNITY_CREATOR, communityTokenAddress, 0);
            assertEq(mainEngine.getProductBaseInfo(userProductID).exists, true);
            // assertEq(mainEngine.getProductBaseInfo(userProductID).approved, false);
        }
    }

    /*//////////////////////////////////////////////////////////////
                             Helper Functions      
    //////////////////////////////////////////////////////////////*/
    // Add this function to your contract or to a separate utility library
    function bytes32ToString(bytes32 _bytes32) public pure returns (string memory) {
        uint8 i = 0;
        while (i < 32 && _bytes32[i] != 0) {
            i++;
        }
        bytes memory bytesArray = new bytes(i);
        for (i = 0; i < 32 && _bytes32[i] != 0; i++) {
            bytesArray[i] = _bytes32[i];
        }
        return string(bytesArray);
    }

    function buyArtBlockTokenMod(address toAccount, uint256 tokenAmount) public {
        vm.startPrank(toAccount);
        artBlockToken.approve(address(mainEngine), tokenAmount * PRECESSION);
        vm.stopPrank();
        uint256 tokenRate = mainEngine.getArtBlockRate();
        uint256 amountToPay = tokenRate * tokenAmount;
        vm.deal(toAccount, amountToPay);
        mainEngine.buyArtBlockToken{ value: amountToPay }(toAccount, tokenAmount);
    }

    function createCommunityMod(address creator) public {
        uint256 createCommunityTokenAmount = mainEngine.getCommunityCreationFee();
        buyArtBlockTokenMod(creator, createCommunityTokenAmount);

        string memory randomString = vm.toString(block.timestamp);
        string memory communityName = string.concat("ART Community ", randomString);
        // communityName = string.concat(communityName, vm.toString(block.timestamp));
        string memory communityDescription = "People can sell their art here";
        string memory tokenName = "PeopleArtToken";
        string memory tokenSymbol = "PAT";

        uint256 tokenRate = mainEngine.getArtBlockRate();
        uint256 amountToPay = tokenRate * TOKEN_AMOUNT;

        vm.startPrank(creator);
        artBlockToken.approve(address(mainEngine), amountToPay);
        vm.stopPrank();
        mainEngine.createCommunity(communityName, communityDescription, tokenName, tokenSymbol, creator);

        COMMUNITY_TOKEN_INDEX += 1;
    }

    function joinCommunity(address user, address communityTokenAddress) public {
        vm.prank(user);
        mainEngine.joinCommunity(communityTokenAddress);
    }

    function buyCommunityTokenMod(address toAccount, uint256 amount, address communityTokenAddress) public {
        uint256 communityTokenCost = mainEngine.getCommunityTokenCost(toAccount, amount, communityTokenAddress);
        buyArtBlockTokenMod(toAccount, communityTokenCost);
        // mainEngine.buyArtBlockToken{ value: communityTokenCost }(toAccount, communityTokenCost);
        mainEngine.buyCommunityToken(toAccount, amount, communityTokenAddress);
        vm.prank(toAccount);
        CustomERC20Token(communityTokenAddress).approve(address(mainEngine), amount * PRECESSION);
    }

    function submitProductToCommunity(address creator, address communityTokenAddress, bool _isExclusive) public {
        string memory randomString = vm.toString(block.timestamp);
        uint256 productPrice = 1000;
        string memory metaData =
            string.concat("https://www.artwork.com Artwork A beautiful piece of art ", randomString);
        bool isExclusive = _isExclusive;
        buyCommunityTokenMod(creator, productPrice, communityTokenAddress);
        vm.startPrank(creator);
        CustomERC20Token(communityTokenAddress).approve(address(mainEngine), productPrice * PRECESSION);
        mainEngine.submitNewProduct(metaData, communityTokenAddress, productPrice, isExclusive);
        vm.stopPrank();
    }

    function tillSubmitProduct(bool isExclusive, address communiCreatorAddress) public {
        // Initial setup
        // uint256 createCommunityTokenAmount = mainEngine.getCommunityCreationFee();
        // buyArtBlockTokenMod(communiCreatorAddress, createCommunityTokenAmount);
        createCommunityMod(communiCreatorAddress);
        address communityTokenAddress = mainEngine.communityTokens(0);
        // Submit product
        submitProductToCommunity(communiCreatorAddress, communityTokenAddress, isExclusive);
    }

    function tillProductApprovedAndStackReturned(bool isExclusive, address communiCreatorAddress) public {
        address communityCreatorAddress = communiCreatorAddress;

        tillSubmitProduct(isExclusive, communityCreatorAddress);
        address communityTokenAddress = mainEngine.communityTokens(0);
        bytes4 userProductID = mainEngine.userProducts(communityCreatorAddress, communityTokenAddress, 0);
        uint256 productSubmittedTime = mainEngine.getProductBaseInfo(userProductID).productSubmittedTime;
        uint256 tokenToMint = 1000;
        bool upVoteORdownVote = true;

        // join community
        for (uint256 i = 1; i <= 5; i++) {
            address user = address(uint160(i));

            vm.startPrank(user);
            mainEngine.joinCommunity(communityTokenAddress);
            vm.stopPrank();

            buyArtBlockTokenMod(user, tokenToMint * i);
            buyCommunityTokenMod(user, tokenToMint * (7 - i), communityTokenAddress);

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
    }

    function test_list_product_to_community_by_author(bool _isExclusive) public {
        address communityCreatorAddress = COMMUNITY_CREATOR;

        bool isExclusive = _isExclusive;
        tillProductApprovedAndStackReturned(isExclusive, communityCreatorAddress);
        address communityTokenAddress = mainEngine.communityTokens(0);
        bytes4 userProductID = mainEngine.userProducts(communityCreatorAddress, communityTokenAddress, 0);

        vm.prank(communityCreatorAddress);

        mainEngine.listProductToAuthorsCommunity(userProductID, communityTokenAddress);

        assertEq(mainEngine.getProductDetailedInfo(userProductID).isListedOnMarketPlace, true);
        assertEq(mainEngine.getProductDetailedInfo(userProductID).currentCommunity, communityTokenAddress);

        // artBlockNFT.ownerOf(artBlockNFT.getTokenId(userProductID));
        if (isExclusive) {
            artBlockNFT.balanceOf(communityCreatorAddress);
            artBlockNFT.getTokenId(userProductID);
            artBlockNFT.ownerOf(0);
        }
    }

    function test_NFT_is_minted_by_community_author() public {
        address communityCreatorAddress = COMMUNITY_CREATOR;

        bool isExclusive = true;
        tillProductApprovedAndStackReturned(isExclusive, communityCreatorAddress);
        address communityTokenAddress = mainEngine.communityTokens(0);
        bytes4 userProductID = mainEngine.userProducts(communityCreatorAddress, communityTokenAddress, 0);

        vm.prank(communityCreatorAddress);

        mainEngine.listProductToAuthorsCommunity(userProductID, communityTokenAddress);

        address nftOwner = artBlockNFT.ownerOf(artBlockNFT.getTokenId(userProductID));

        assertEq(nftOwner, communityCreatorAddress);
    }

    function listProductInitiallyToAuthorsCommunity(address communiCreatorAddress) public {
        bool isExclusive = true;
        tillProductApprovedAndStackReturned(isExclusive, communiCreatorAddress);
        mainEngine.getAllCommunities();
        address communityTokenAddress = mainEngine.communityTokens(0);
        bytes4 userProductID = mainEngine.userProducts(communiCreatorAddress, communityTokenAddress, 0);

        vm.prank(communiCreatorAddress);
        mainEngine.listProductToAuthorsCommunity(userProductID, communityTokenAddress);
    }

    function test_buy_Exclusive_product_from_a_community() public {
        address communityCreatorAddress = COMMUNITY_CREATOR;

        listProductInitiallyToAuthorsCommunity(communityCreatorAddress);
        address communityTokenAddress = mainEngine.communityTokens(0);
        bytes4 userProductID = mainEngine.userProducts(communityCreatorAddress, communityTokenAddress, 0);
        uint256 productPrice = mainEngine.getProductDetailedInfo(userProductID).price;
        buyCommunityTokenMod(USER_2, productPrice, communityTokenAddress);
        // if product is exclusive
        bool isExclusive = mainEngine.getProductBaseInfo(userProductID).isExclusive;

        if (isExclusive) {
            vm.startPrank(communityCreatorAddress);
            artBlockNFT.approve(address(mainEngine), artBlockNFT.getTokenId(userProductID));
            vm.stopPrank();
        }

        vm.startPrank(USER_2);
        mainEngine.joinCommunity(communityTokenAddress);
        // approve community token to used by mainContract
        CustomERC20Token(communityTokenAddress).approve(address(mainEngine), productPrice * PRECESSION);
        mainEngine.buyProduct(userProductID, communityTokenAddress);
        vm.stopPrank();

        assertEq(mainEngine.getProductDetailedInfo(userProductID).isListedOnMarketPlace, false);
        assertEq(mainEngine.getProductDetailedInfo(userProductID).currentCommunity, address(0));
        assertEq(mainEngine.getProductDetailedInfo(userProductID).currentOwner, USER_2);
        assertEq(CustomERC20Token(communityTokenAddress).balanceOf(USER_2), 0);
    }

    function test_increase_points_after_buying_product() public {
        address communityCreatorAddress = COMMUNITY_CREATOR;

        listProductInitiallyToAuthorsCommunity(communityCreatorAddress);
        address communityTokenAddress = mainEngine.communityTokens(0);
        bytes4 userProductID = mainEngine.userProducts(communityCreatorAddress, communityTokenAddress, 0);
        uint256 productPrice = mainEngine.getProductDetailedInfo(userProductID).price;
        buyCommunityTokenMod(USER_2, productPrice, communityTokenAddress);
        // if product is exclusive
        bool isExclusive = mainEngine.getProductBaseInfo(userProductID).isExclusive;

        if (isExclusive) {
            vm.startPrank(communityCreatorAddress);
            artBlockNFT.approve(address(mainEngine), artBlockNFT.getTokenId(userProductID));
            vm.stopPrank();
        }

        vm.startPrank(USER_2);
        mainEngine.joinCommunity(communityTokenAddress);
        // approve community token to used by mainContract
        CustomERC20Token(communityTokenAddress).approve(address(mainEngine), productPrice * PRECESSION);
        mainEngine.buyProduct(userProductID, communityTokenAddress);
        vm.stopPrank();
        assertEq(
            mainEngine.getUserActivityPoints(USER_2, communityTokenAddress),
            mainEngine.getCommunityActivityPoints(communityTokenAddress)
        );
    }

    function test_buy_product_from_community_then_list_it_to_own_community() public {
        address communityCreatorAddress = COMMUNITY_CREATOR;

        listProductInitiallyToAuthorsCommunity(communityCreatorAddress);
        address communityTokenAddress = mainEngine.communityTokens(0);
        console.log("Old Community Address: ", communityTokenAddress);
        bytes4 userProductID = mainEngine.userProducts(communityCreatorAddress, communityTokenAddress, 0);
        uint256 productPrice = mainEngine.getProductDetailedInfo(userProductID).price;
        buyCommunityTokenMod(USER_2, productPrice, communityTokenAddress);
        // if product is exclusive
        bool isExclusive = mainEngine.getProductBaseInfo(userProductID).isExclusive;

        if (isExclusive) {
            vm.startPrank(communityCreatorAddress);
            artBlockNFT.approve(address(mainEngine), artBlockNFT.getTokenId(userProductID));
            vm.stopPrank();
        }

        vm.startPrank(USER_2);
        mainEngine.joinCommunity(communityTokenAddress);
        // approve community token to used by mainContract
        CustomERC20Token(communityTokenAddress).approve(address(mainEngine), productPrice * PRECESSION);
        mainEngine.buyProduct(userProductID, communityTokenAddress);
        vm.stopPrank();

        // create new community
        createCommunityMod(USER_2);
        address newCommunityAddress = mainEngine.communityTokens(1);
        // console.log("New Community Address: ", newCommunityAddress);

        uint256 newPriceForProduct = 2000;

        vm.prank(USER_2);
        mainEngine.listPurchasedProductToOwnCommunity(userProductID, newPriceForProduct, newCommunityAddress);

        // checking if the product is listed to the new community
        assertEq(mainEngine.getProductDetailedInfo(userProductID).isListedOnMarketPlace, true);
        assertEq(mainEngine.getProductDetailedInfo(userProductID).currentCommunity, newCommunityAddress);
        assertEq(mainEngine.getProductDetailedInfo(userProductID).currentOwner, USER_2);
        assertEq(mainEngine.getProductDetailedInfo(userProductID).price, newPriceForProduct);
    }

    function test_buy_product_from_community_then_list_it_to_other_community() public {
        address communityCreatorAddress = COMMUNITY_CREATOR;
        address newCommunityOwner = makeAddr("newCommunityOwner");

        listProductInitiallyToAuthorsCommunity(communityCreatorAddress);
        address communityTokenAddress = mainEngine.communityTokens(0);
        console.log("Old Community Address: ", communityTokenAddress);
        bytes4 userProductID = mainEngine.userProducts(communityCreatorAddress, communityTokenAddress, 0);
        uint256 productPrice = mainEngine.getProductDetailedInfo(userProductID).price;
        buyCommunityTokenMod(USER_2, productPrice, communityTokenAddress);
        // if product is exclusive
        bool isExclusive = mainEngine.getProductBaseInfo(userProductID).isExclusive;

        if (isExclusive) {
            vm.startPrank(communityCreatorAddress);
            artBlockNFT.approve(address(mainEngine), artBlockNFT.getTokenId(userProductID));
            vm.stopPrank();
        }

        vm.startPrank(USER_2);
        mainEngine.joinCommunity(communityTokenAddress);
        // approve community token to used by mainContract
        CustomERC20Token(communityTokenAddress).approve(address(mainEngine), productPrice * PRECESSION);
        mainEngine.buyProduct(userProductID, communityTokenAddress);
        vm.stopPrank();

        // create new community by newCommunityOwner
        createCommunityMod(newCommunityOwner);
        address newCommunityAddress = mainEngine.communityTokens(1);
        // console.log("New Community Address: ", newCommunityAddress);

        uint256 newPriceForProduct = 2000;

        uint256 feeForlisting = newPriceForProduct / 10;

        buyCommunityTokenMod(USER_2, feeForlisting, newCommunityAddress);
        vm.startPrank(USER_2);
        // CustomERC20Token(newCommunityAddress).approve(address(mainEngine), feeForlisting * PRECESSION);
        mainEngine.listProductToOtherCommunityForSelling(userProductID, newPriceForProduct, newCommunityAddress);
        vm.stopPrank();

        // checking if the product is listed to the new community
        assertEq(mainEngine.getProductDetailedInfo(userProductID).isListedOnMarketPlace, true);
        assertEq(mainEngine.getProductDetailedInfo(userProductID).currentCommunity, newCommunityAddress);
        assertEq(mainEngine.getProductDetailedInfo(userProductID).currentOwner, USER_2);
        assertEq(mainEngine.getProductDetailedInfo(userProductID).price, newPriceForProduct);
    }
}
