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

import { console } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IMainEngine {
    // function getProductBaseInfo(bytes4 productId) external view returns (ProductBase memory);
    function getTokenAddress() external view returns (address);
    function getProductStatus(bytes4 productId) external view returns (bool);
    function getProductSubmittedTime(bytes4 productId) external view returns (uint256);
}

contract VotingContract {
    ///////////////
    /// Errors ////
    ///////////////

    error VotingContract__ProductDoesntExist(bytes4 productId);
    error VotingContract__ProductAlreadyApproved(bytes4 productId);
    error VotingContract__VotingOnGoing(bytes4 productId);

    /////////////////////////
    //   State Variables  //
    ////////////////////////
    address private immutable mainEngineAddress;
    address private immutable artBlockToken;
    uint256 private constant VOTING_DURATION = 7 days;

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct ProductVotingInfo {
        uint256 upvotes;
        uint256 downvotes;
        bool approved;
    }

    /*//////////////////////////////////////////////////////////////
                                MAPPINGS
    //////////////////////////////////////////////////////////////*/
    mapping(bytes4 productID => ProductVotingInfo) public productsVotingInfo;

    ////////////////
    //   Events  //
    ////////////////
    event VoteCasted(bytes4 indexed productId, address indexed communityToken, bool indexed isUPVote);
    event VotesCounted(uint256 indexed productId);

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

    /**
     * @notice Constructor to initialize the VotingContract
     * @param _mainEngineAddress Address of the main engine contract
     */
    constructor(address _mainEngineAddress) {
        mainEngineAddress = _mainEngineAddress;
        artBlockToken = IMainEngine(mainEngineAddress).getTokenAddress();
    }

    /**
     * @notice Cast a vote for a product
     * @param productId ID of the product to vote for
     * @param communityToken Address of the community token
     * @param isUPVote Boolean indicating if the vote is an upvote
     */
    function voteForProduct(bytes4 productId, address communityToken, bool isUPVote) external {
        if (!IMainEngine(mainEngineAddress).getProductStatus(productId)) {
            revert VotingContract__ProductDoesntExist(productId);
        }

        if (productsVotingInfo[productId].approved) {
            revert VotingContract__ProductAlreadyApproved(productId);
        }

        if (isUPVote) {
            productsVotingInfo[productId].upvotes += calculateVoteWeight(msg.sender, communityToken);
        } else {
            productsVotingInfo[productId].downvotes += calculateVoteWeight(msg.sender, communityToken);
        }
        emit VoteCasted(productId, communityToken, isUPVote);
    }

    /**
     * @notice Calculate the voting result for a product
     * @param productId ID of the product to calculate the voting result for
     */
    function calculateVotingResult(bytes4 productId) external onlyMainEngine {
        ProductVotingInfo memory productBase = productsVotingInfo[productId];

        if (productBase.approved) {
            revert VotingContract__ProductAlreadyApproved(productId);
        }

        if (IMainEngine(mainEngineAddress).getProductSubmittedTime(productId) + VOTING_DURATION >= block.timestamp) {
            revert VotingContract__VotingOnGoing(productId);
        }

        if (productBase.upvotes > productBase.downvotes) {
            productsVotingInfo[productId].approved = true;
        }
    }

    //////////////////////////////
    /// Internal View Functions //
    //////////////////////////////

    /**
     * @notice Calculate the vote weight based on user's token balances
     * @param user Address of the user
     * @param community Address of the community token
     * @return totalVotes Calculated vote weight
     */
    function calculateVoteWeight(address user, address community) internal view returns (uint256 totalVotes) {
        uint256 userCommunitytoken = IERC20(community).balanceOf(user);
        uint256 userArtBlockToken = IERC20(artBlockToken).balanceOf(user);
        uint256 communityTokenWeight = (userCommunitytoken * 6) / 10; // 60% weightage of the
            // community token
        uint256 artblockTokenWeight = (userArtBlockToken * 4) / 10; // 40% weightage of the artblock
            // token
        totalVotes = (communityTokenWeight + artblockTokenWeight) / 1 ether;
    }

    //////////////////////////////
    ///// Getter Functions  //////
    //////////////////////////////

    function getProductVotingInfo(bytes4 productId) external view returns (ProductVotingInfo memory) {
        return productsVotingInfo[productId];
    }

    function getVotingDuration() external pure returns (uint256) {
        return VOTING_DURATION;
    }

    function isApproved(bytes4 productId) external view returns (bool) {
        return productsVotingInfo[productId].approved;
    }

    function getVotingWeight(address user, address community) external view returns (uint256) {
        return calculateVoteWeight(user, community);
    }
}
