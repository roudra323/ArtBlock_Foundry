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

    /////////////////////////
    //   State Variables  //
    ////////////////////////
    address private immutable mainEngineAddress;
    address private immutable artBlockToken;

    uint256 private constant VOTING_PRECISION = 10e8;
    uint256 private constant RATE_CHANGE_COOLDOWN = 2 weeks;

    uint256 private initialRateOfCommunityToken = 1;

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
        // artBlockToken = IMainEngine(mainEngineAddress).getTokenAddress();
    }

    //////////////////////////
    //  External Functions  //
    //////////////////////////
    function proposeRateChange(
        address communityToken,
        uint256 proposedRate,
        uint256 votingDuration
    )
        external
        onlyCommunityMember(communityToken)
    {
        if (block.timestamp < lastRateChangeTime[communityToken] + RATE_CHANGE_COOLDOWN) {
            revert ArtBlockGovernance__RateChangeTooSoon();
        }

        uint256 proposalIndex = rateChangeProposals.length;
        initializeRateChangeProposal(proposalIndex, communityToken, proposedRate, block.timestamp + votingDuration);
    }

    function initializeRateChangeProposal(
        uint256 proposalIndex,
        address communityToken,
        uint256 proposedRate,
        uint256 votingEndTime
    )
        internal
    {
        RateChangeProposal storage proposal = rateChangeProposals[proposalIndex];
        proposal.communityToken = communityToken;
        proposal.proposedRate = proposedRate;
        proposal.votingEndTime = votingEndTime;
        proposal.exists = true;
    }

    function voteOnRateChange(uint256 proposalIndex, bool vote) external {
        if (proposalIndex >= rateChangeProposals.length) {
            revert ArtBlockGovernance__InvalidProposalIndex();
        }

        RateChangeProposal storage proposal = rateChangeProposals[proposalIndex];
        if (block.timestamp >= proposal.votingEndTime) {
            revert ArtBlockGovernance__VotingEnded();
        }
        if (proposal.votes[msg.sender]) {
            revert ArtBlockGovernance__AlreadyVoted();
        }

        proposal.votes[msg.sender] = true;
        if (vote) {
            proposal.votesFor += 1;
        } else {
            proposal.votesAgainst += 1;
        }
    }

    function finalizeRateChange(uint256 proposalIndex) external {
        if (proposalIndex >= rateChangeProposals.length) {
            revert ArtBlockGovernance__InvalidProposalIndex();
        }

        RateChangeProposal storage proposal = rateChangeProposals[proposalIndex];
        if (block.timestamp < proposal.votingEndTime) {
            revert ArtBlockGovernance__VotingOngoing();
        }

        uint256 totalVotes = proposal.votesFor + proposal.votesAgainst;
        uint256 threshold = (totalVotes * 60 * VOTING_PRECISION) / 100; // Assuming 60% voting threshold

        if (proposal.votesFor * VOTING_PRECISION >= threshold) {
            communityTokenRate[proposal.communityToken] = proposal.proposedRate;
            lastRateChangeTime[proposal.communityToken] = block.timestamp;
        }
    }

    function updateCommunityTokenRate(address communityToken, uint256 newRate) public onlyMainEngine {
        communityTokenRate[communityToken] = newRate;
        lastRateChangeTime[communityToken] = block.timestamp;
    }

    function getCommunityTokenRate(address communityToken) external view returns (uint256) {
        return communityTokenRate[communityToken];
    }
}
