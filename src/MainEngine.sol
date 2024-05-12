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

import {CustomERC20Token} from "./CustomERC20Token.sol";

contract MainEngine {
    ///////////////
    /// Errors ////
    ///////////////
    error MainEngine__TransferFailed();
    error MainEngine__InSufficientAmount();

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
    }

    //////////////////////
    ////// Mappings  /////
    //////////////////////

    mapping(address communityToken => CommunityInfo) public communityInfo;
    mapping(address communityCreator => CommunityInfo[]) public creatorCommunities;

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

    /////////////////
    //  Functions  //
    /////////////////

    constructor() {
        artBlockToken = new CustomERC20Token("ARTBLOCKTOKEN", "ABT", address(this));
        creatorProtocol = msg.sender;
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
    ) external payable {
        if (artBlockToken.balanceOf(communityCreator) < 1000) {
            revert MainEngine__InSufficientAmount();
        }
        artBlockToken.burnFrom(communityCreator, 1000);
        CustomERC20Token communityToken = new CustomERC20Token(tokenName, tokenSymbol, communityCreator); // have to approve the engine to access the tokens
        communityTokens.push(address(communityToken));
        CommunityInfo memory newCommunity =
            CommunityInfo(communityName, communityDescription, tokenName, tokenSymbol, communityCreator);
        emit CommunityCreated(communityName, communityCreator, address(communityToken));
        communityInfo[address(communityToken)] = newCommunity;
        creatorCommunities[communityCreator].push(newCommunity);
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
        (bool success,) = creatorProtocol.call{value: tokenAmount}("");
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
