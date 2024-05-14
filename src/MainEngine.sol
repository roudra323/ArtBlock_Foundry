// SPDX-License-Identifier: MIT

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

pragma solidity ^0.8.20;

import { CustomERC20Token } from "./CustomERC20Token.sol";

contract MainEngine {
    ///////////////
    /// Errors ////
    ///////////////
    error MainEngine__TransferFailed();
    error MainEngine__InSufficientAmount();
    error MainEngine__JoinCommunityFailed();
    error MainEngine__AlreadyAMember();

    /////////////////////////
    //   State Variables  //
    ////////////////////////

    address private immutable creatorProtocol;
    CustomERC20Token private immutable artBlockToken;

    //////////////////////
    ////// Structs  //////
    //////////////////////

    struct CommunityInfo {
        string communityName;
        string communityDescription;
        string tokenName;
        string tokenSymbol;
        address communityCreator;
        uint256 totalMembers;
    }

    //////////////////////
    ////// Mappings  /////
    //////////////////////

    mapping(address communityToken => CommunityInfo) public communityInfo;
    mapping(address communityCreator => CommunityInfo[]) public creatorCommunities;
    mapping(address user => address[] communityTokens) public userCommunities;
    mapping(address user => mapping(address communityToken => bool isMember)) public isCommunityMember;

    /////////////////////
    ////// Arrays  /////
    ////////////////////
    address[] public communityTokens;

    ////////////////
    //   Events  //
    ////////////////
    event ABTBoughtByUser(address indexed user, uint256 indexed amountABT);
    event CommunityCreated(
        string indexed communityName, address indexed communityCreator, address indexed communityToken
    );
    event JoinedCommunity(address indexed user, address indexed communityToken);

    /////////////////
    //  Functions  //
    /////////////////

    constructor() {
        creatorProtocol = msg.sender;
        artBlockToken = new CustomERC20Token("ARTBLOCKTOKEN", "ABT", creatorProtocol);
    }

    //////////////////////////
    //  External Functions  //
    //////////////////////////

    /*
     * @notice Function to create a new community
     * @param communityName name of the community
     * @param communityDescription description of the community
     * @param tokenName name of the community token
     * @param tokenSymbol symbol of the community token
     * @param communityCreator address of the creator of the community
     */
    function createCommunity(
        string memory communityName,
        string memory communityDescription,
        string memory tokenName,
        string memory tokenSymbol,
        address communityCreator
    )
        external
        payable
    {
        // Minimum amount to create a communinity is 1000 ABT
        if (artBlockToken.balanceOf(communityCreator) < 1000) {
            revert MainEngine__InSufficientAmount();
        }
        artBlockToken.burnFrom(communityCreator, 1000);
        CustomERC20Token communityToken = new CustomERC20Token(tokenName, tokenSymbol, communityCreator);
        communityTokens.push(address(communityToken));
        CommunityInfo memory newCommunity =
            CommunityInfo(communityName, communityDescription, tokenName, tokenSymbol, communityCreator, 1);
        communityInfo[address(communityToken)] = newCommunity;
        creatorCommunities[communityCreator].push(newCommunity);
        emit CommunityCreated(communityName, communityCreator, address(communityToken));
    }

    function joinCommunity(address tokenAddress) external {
        // Join the community
        if (communityInfo[tokenAddress].communityCreator == address(0)) {
            revert MainEngine__JoinCommunityFailed();
        }
        if (isCommunityMember[msg.sender][tokenAddress] == true) {
            revert MainEngine__AlreadyAMember();
        }
        communityInfo[tokenAddress].totalMembers += 1;
        isCommunityMember[msg.sender][tokenAddress] = true;
        userCommunities[msg.sender].push(tokenAddress);

        emit JoinedCommunity(msg.sender, tokenAddress);
    }

    /*
     * @notice Function to buy ArtBlock token by sending ether
     * @param to address of the user who is buying the ArtBlock token
     * @param amount number of ArtBlock tokens to buy
     */
    function buyArtBlockToken(address to, uint256 amount) public payable {
        uint256 tokenAmount = 1000 wei * amount; // 1 ArtBlock token = 1000 wei
        // check if the user has sent the specified amount of ether to buy the ABX token
        if (tokenAmount != msg.value) {
            revert MainEngine__InSufficientAmount();
        }
        (bool success,) = creatorProtocol.call{ value: tokenAmount }("");
        // check if the transfer of ABT is successful
        if (!success) {
            revert MainEngine__TransferFailed();
        }
        artBlockToken.mint(to, amount);
        emit ABTBoughtByUser(to, amount);
    }

    /////////////////////////////
    //  view & pure Functions  //
    /////////////////////////////

    function getTokenAddress() public view returns (address) {
        return address(artBlockToken);
    }

    function getCreatorProtocol() public view returns (address) {
        return creatorProtocol;
    }
}
