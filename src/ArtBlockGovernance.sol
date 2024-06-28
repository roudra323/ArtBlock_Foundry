// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IMainEngine {
    function isCommunityMembr(address user, address communityToken) external view returns (bool);
    function getTokenAddress() external view returns (address);
}

contract ArtBlockGovernance {
    ///////////////
    /// Errors ////
    ///////////////
    error ArtBlockGovernance__OnlyMainEngineCanCall();
    error ArtBlockGovernance__VotingOngoing();
    error ArtBlockGovernance__VotingEnded();
    error ArtBlockGovernance__AlreadyVoted();
    error ArtBlockGovernance__InvalidProposalIndex();
    error ArtBlockGovernance__NotCommunityMember();
    error ArtBlockGovernance__RateChangeTooSoon();
    error ArtBlockGovernance__InvalidRate();
    error ArtBlockGovernance__DidntMeetThreshold();

    /////////////////////////
    //   State Variables  //
    ////////////////////////
    address private immutable mainEngineAddress;
    address private immutable artBlockToken;

    uint256 private constant VOTING_PRECISION = 10e8;
    uint256 private constant PRECISION = 10e18;
    uint256 private constant RATE_CHANGE_COOLDOWN = 2 weeks;
    uint256 private constant VOTING_DURATION = 14 days;

    uint256 private initialRateOfCommunityToken = 1;

    uint256 public constant MIN_RATE = 0.5e18; // 0.5 ArtBlock per Community Token
    uint256 public constant MAX_RATE = 2e18; // 2 ArtBlock per Community Token
    uint256 public constant MAX_RATE_CHANGE = 0.1e18; // 10% max change per proposal

    //////////////////////
    ////// Structs  //////
    //////////////////////
    struct RateChangeProposal {
        address communityToken;
        uint256 proposedRate;
        uint256 votingEndTime;
        mapping(address => bool) votes;
        uint256 votesFor;
        uint256 votesAgainst;
        bool exists;
        string reason;
    }

    //////////////////////
    ////// Mappings  /////
    //////////////////////
    mapping(address => uint256) public communityTokenRate;
    mapping(address => uint256) public lastRateChangeTime;

    /////////////////////
    ////// Arrays  /////
    /////////////////////
    RateChangeProposal[] public rateChangeProposals;

    ////////////////
    //  Modifiers //
    ////////////////

    modifier onlyMainEngine() {
        if (msg.sender != mainEngineAddress) {
            revert ArtBlockGovernance__OnlyMainEngineCanCall();
        }
        _;
    }

    modifier onlyCommunityMember(address communityToken) {
        if (!IMainEngine(mainEngineAddress).isCommunityMembr(msg.sender, communityToken)) {
            revert ArtBlockGovernance__NotCommunityMember();
        }
        _;
    }

    /////////////////
    //  Functions  //
    /////////////////

    constructor() {
        mainEngineAddress = msg.sender;
        artBlockToken = IMainEngine(mainEngineAddress).getTokenAddress();
    }

    //////////////////////////
    //  External Functions  //
    //////////////////////////

    /**
     * @notice Propose a rate change for a community token
     * @param communityToken Address of the community token
     * @param proposedRate The proposed new rate
     * @param reason Reason for proposing the rate change
     */
    function proposeRateChange(
        address communityToken,
        uint256 proposedRate,
        string memory reason
    )
        external
        onlyCommunityMember(communityToken)
    {
        if (block.timestamp < lastRateChangeTime[communityToken] + RATE_CHANGE_COOLDOWN) {
            revert ArtBlockGovernance__RateChangeTooSoon();
        }

        if (proposedRate < MIN_RATE || proposedRate > MAX_RATE) {
            revert ArtBlockGovernance__InvalidRate();
        }

        uint256 proposalIndex = rateChangeProposals.length;
        initializeRateChangeProposal(
            proposalIndex, communityToken, proposedRate, block.timestamp + VOTING_DURATION, reason
        );
    }

    /**
     * @notice Vote on a rate change proposal
     * @param proposalIndex Index of the proposal
     * @param vote Boolean indicating whether to vote for (true) or against (false) the proposal
     */
    function voteOnRateChange(uint256 proposalIndex, bool vote) external {
        if (proposalIndex >= rateChangeProposals.length) {
            revert ArtBlockGovernance__InvalidProposalIndex();
        }

        if (block.timestamp >= rateChangeProposals[proposalIndex].votingEndTime) {
            revert ArtBlockGovernance__VotingEnded();
        }
        if (rateChangeProposals[proposalIndex].votes[msg.sender]) {
            revert ArtBlockGovernance__AlreadyVoted();
        }

        rateChangeProposals[proposalIndex].votes[msg.sender] = true;
        if (vote) {
            rateChangeProposals[proposalIndex].votesFor +=
                calculateVoteWeight(msg.sender, rateChangeProposals[proposalIndex].communityToken);
        } else {
            rateChangeProposals[proposalIndex].votesAgainst +=
                calculateVoteWeight(msg.sender, rateChangeProposals[proposalIndex].communityToken);
        }
    }

    /**
     * @notice Finalize a rate change proposal after the voting period has ended
     * @param proposalIndex Index of the proposal
     */
    function finalizeRateChange(uint256 proposalIndex) external {
        if (proposalIndex >= rateChangeProposals.length) {
            revert ArtBlockGovernance__InvalidProposalIndex();
        }

        // RateChangeProposal memory proposal = rateChangeProposals[proposalIndex];
        if (block.timestamp < rateChangeProposals[proposalIndex].votingEndTime) {
            revert ArtBlockGovernance__VotingOngoing();
        }

        uint256 totalVotes =
            rateChangeProposals[proposalIndex].votesFor + rateChangeProposals[proposalIndex].votesAgainst;
        uint256 threshold = (totalVotes * 60 * VOTING_PRECISION) / (100 * PRECISION); // Assuming 60% voting threshold

        if ((rateChangeProposals[proposalIndex].votesFor * VOTING_PRECISION) / PRECISION < threshold) {
            revert ArtBlockGovernance__DidntMeetThreshold();
        }

        communityTokenRate[rateChangeProposals[proposalIndex].communityToken] =
            rateChangeProposals[proposalIndex].proposedRate;
        lastRateChangeTime[rateChangeProposals[proposalIndex].communityToken] = block.timestamp;
    }

    /**
     * @notice Update the rate of a community token (can only be called by the main engine)
     * @param communityToken Address of the community token
     * @param newRate New rate to set
     */
    function updateCommunityTokenRate(address communityToken, uint256 newRate) external onlyMainEngine {
        communityTokenRate[communityToken] = newRate;
        lastRateChangeTime[communityToken] = block.timestamp;
    }

    //////////////////////////
    //  internal Functions  //
    //////////////////////////

    /**
     * @notice Initialize a new rate change proposal
     * @param proposalIndex Index of the proposal
     * @param communityToken Address of the community token
     * @param proposedRate Proposed new rate
     * @param votingEndTime End time of the voting period
     * @param reason Reason for proposing the rate change
     */
    function initializeRateChangeProposal(
        uint256 proposalIndex,
        address communityToken,
        uint256 proposedRate,
        uint256 votingEndTime,
        string memory reason
    )
        internal
    {
        rateChangeProposals[proposalIndex].communityToken = communityToken;
        rateChangeProposals[proposalIndex].proposedRate = proposedRate;
        rateChangeProposals[proposalIndex].votingEndTime = votingEndTime;
        rateChangeProposals[proposalIndex].exists = true;
        rateChangeProposals[proposalIndex].reason = reason;
        communityTokenRate[communityToken] = proposedRate;
    }

    /**
     * @notice Calculate the vote weight based on user's token balances
     * @param user Address of the user
     * @param community Address of the community token
     * @return totalVotes Calculated vote weight
     */
    function calculateVoteWeight(address user, address community) internal view returns (uint256 totalVotes) {
        uint256 userCommunitytoken = IERC20(community).balanceOf(user);
        uint256 userArtBlockToken = IERC20(artBlockToken).balanceOf(user);
        uint256 communityTokenWeight = (userCommunitytoken * 6) / 10; // 60% weightage of the community token
        uint256 artblockTokenWeight = (userArtBlockToken * 4) / 10; // 40% weightage of the artblock token
        totalVotes = (communityTokenWeight + artblockTokenWeight);
    }

    /////////////////////////////
    //  view & pure functions  //
    /////////////////////////////

    /**
     * @notice Get the current rate of a community token
     * @param communityToken Address of the community token
     * @return Current rate of the community token
     */
    function getCommunityTokenRate(address communityToken) external view returns (uint256) {
        return communityTokenRate[communityToken];
    }

    /**
     * @notice Check if a community token is ready for a rate change
     * @param communityToken Address of the community token
     * @return Boolean indicating if the community token is ready for a rate change
     */
    function isReadyForRateChange(address communityToken) external view returns (bool) {
        return block.timestamp >= lastRateChangeTime[communityToken] + RATE_CHANGE_COOLDOWN;
    }

    /**
     * @notice Check if a rate change proposal is ready to be initiated
     * @param proposalIndex Index of the proposal
     * @return Boolean indicating if the proposal is ready to be initiated
     */
    function isReadyToInitiateRateChange(uint256 proposalIndex) external view returns (bool) {
        return proposalIndex < rateChangeProposals.length
            && block.timestamp >= rateChangeProposals[proposalIndex].votingEndTime;
    }
}
