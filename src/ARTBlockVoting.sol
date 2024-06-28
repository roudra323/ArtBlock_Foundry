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

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

struct ProductBase {
    uint256 stakeAmount;
    uint256 upvotes;
    uint256 downvotes;
    uint256 productSubmittedTime;
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
    error VotingContract__VotingOnGoing(bytes4 productId);

    /////////////////////////
    //   State Variables  //
    ////////////////////////
    address private immutable mainEngineAddress;
    address private immutable artBlockToken;
    uint256 private constant VOTING_PRECISION = 10e8;
    uint256 private constant VOTING_DURATION = 7 days;

    //////////////////////
    ////// Mappings  /////
    //////////////////////
    mapping(bytes4 productID => ProductBase) public productsVotingInfo;

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
        ProductBase memory productBase = productsVotingInfo[productId];

        if (!IMainEngine(mainEngineAddress).getProductBaseInfo(productId).exists) {
            revert VotingContract__ProductDoesntExist(productId);
        }

        if (productBase.approved) {
            revert VotingContract__ProductAlreadyApproved(productId);
        }

        if (isUPVote) {
            productBase.upvotes += calculateVoteWeight(msg.sender, communityToken);
        } else {
            productBase.downvotes += calculateVoteWeight(msg.sender, communityToken);
        }
        emit VoteCasted(productId, communityToken, isUPVote);
    }

    /**
     * @notice Calculate the voting result for a product
     * @param productId ID of the product to calculate the voting result for
     */
    function calculateVotingResult(bytes4 productId) external view onlyMainEngine {
        ProductBase memory productBase = productsVotingInfo[productId];

        if (productBase.approved) {
            revert VotingContract__ProductAlreadyApproved(productId);
        }

        if (
            IMainEngine(mainEngineAddress).getProductBaseInfo(productId).productSubmittedTime + VOTING_DURATION
                >= block.timestamp
        ) {
            revert VotingContract__VotingOnGoing(productId);
        }

        if (productBase.upvotes > productBase.downvotes) {
            productBase.approved = true;
            productBase.exists = true;
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
        uint256 communityTokenWeight = (userCommunitytoken * 6 * VOTING_PRECISION) / 10; // 60% weightage of the
            // community token

        uint256 artblockTokenWeight = (userArtBlockToken * 4 * VOTING_PRECISION) / 10; // 40% weightage of the artblock
            // token
        totalVotes = (communityTokenWeight + artblockTokenWeight);
    }

    //////////////////////////////
    ///// Getter Functions  //////
    //////////////////////////////

    function getProductVotingInfo(bytes4 productId) external view returns (ProductBase memory) {
        return productsVotingInfo[productId];
    }

    function getVotingDuration() external pure returns (uint256) {
        return VOTING_DURATION;
    }

    function isApproved(bytes4 productId) external view returns (bool) {
        return productsVotingInfo[productId].approved;
    }

    /**
     * @notice Converts bytes4 to uint32
     * @param input bytes4 input
     * @return output uint32 output
     */
    function bytes4ToUint32(bytes4 input) public pure returns (uint32 output) {
        output = (uint32(bytes4(input)));
    }
}
