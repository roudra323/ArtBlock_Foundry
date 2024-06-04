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

pragma solidity ^0.8.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

struct ProductBase {
    uint256 stakeAmount;
    uint256 upvotes;
    uint256 downvotes;
    bool approved;
    bool exists;
}

interface IMainEngine {
    function getProductBaseInfo(bytes32 productId) external view returns (ProductBase memory);
    function getTokenAddress() external view returns (address);
}

contract VotingContract {
    ///////////////
    /// Errors ////
    ///////////////

    error VotingContract__ProductDoesntExist(bytes4 productId);
    error VotingContract__ProductAlreadyApproved(bytes4 productId);

    /////////////////////////
    //   State Variables  //
    ////////////////////////
    address private immutable mainEngineAddress;
    address private immutable artBlockToken;
    uint256 private constant VOTING_PRECISION = 10e8;

    //////////////////////
    ////// Mappings  /////
    //////////////////////
    mapping(bytes4 productID => ProductBase) public productsVotingInfo;

    ////////////////
    //   Events  //
    ////////////////
    event ProductAdded(uint256 id);
    event VoteCasted(bytes4 productId);
    event VotesCounted(uint256 productId);

    ////////////////
    //  Modifiers //
    ////////////////

    modifier onlyMainEngine() {
        require(msg.sender == mainEngineAddress, "Only main engine can call");
        _;
    }
    /////////////////
    //  Functions  //
    /////////////////

    constructor(address _mainEngineAddress) {
        mainEngineAddress = _mainEngineAddress;
        artBlockToken = IMainEngine(mainEngineAddress).getTokenAddress();
    }

    function voteForProduct(bytes4 productId) external {
        ProductBase storage productBase = productsVotingInfo[productId];

        if (!IMainEngine(mainEngineAddress).getProductBaseInfo(productId).exists) {
            revert VotingContract__ProductDoesntExist(productId);
        }

        if (productBase.approved) {
            revert VotingContract__ProductAlreadyApproved(productId);
        }

        productBase.upvotes += calculateVote(msg.sender, artBlockToken);
        emit VoteCasted(productId);
    }

    function calculateVote(address user, address community) internal view returns (uint256 totalVotes) {
        uint256 userCommunitytoken = IERC20(community).balanceOf(user);
        uint256 userArtBlockToken = IERC20(artBlockToken).balanceOf(user);
        uint256 communityTokenWeight = (userCommunitytoken * 6 * VOTING_PRECISION) / 10; // 60% weightage
        uint256 artblockTokenWeight = (userArtBlockToken * 4 * VOTING_PRECISION) / 10; // 40% weightage
        totalVotes = (communityTokenWeight + artblockTokenWeight) / VOTING_PRECISION;
    }
}
