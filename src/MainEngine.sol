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

pragma solidity ^0.8.23;

import { CustomERC20Token } from "./CustomERC20Token.sol";

interface IVotingContract {
    function isApproved(bytes4 productId) external view returns (bool);
    function calculateVotingResult(bytes4 productId) external;
    function getVotingDuration() external pure returns (uint256);
}

contract MainEngine {
    ///////////////
    /// Errors ////
    ///////////////
    error MainEngine__TransferFailed();
    error MainEngine__InSufficientAmount();
    error MainEngine__JoinCommunityFailed();
    error MainEngine__AlreadyAMember();
    error MainEngine__ProductAlreadyExists();
    error MainEngine__ProductNotApproved();
    error MainEngine__UnAuthorised();

    /////////////////////////
    //   State Variables  //
    ////////////////////////

    address private immutable creatorProtocol;
    CustomERC20Token private immutable artBlockToken;
    address private govContract;
    address private votingContractAddr;

    uint256 private PRECESSION = 10 ** 8;

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

    struct ProductBase {
        uint256 stakeAmount;
        bool stackReturned;
        uint256 upvotes;
        uint256 downvotes;
        uint256 productSubmittedTime;
        bool approved;
        bool exists;
    }

    struct Product {
        string metadata; // Metadata about the product (e.g., title, description, URL)
        uint256 price; // Price of the product
        bool isListedForResell;
        bool isListedOnMarketPlace;
        address author;
        address currentOwner;
        address currentCommunity;
    }

    //////////////////////
    ////// Mappings  /////
    //////////////////////

    mapping(address communityToken => CommunityInfo) public communityInfo;
    mapping(address communityCreator => CommunityInfo[]) public creatorCommunities;
    mapping(address user => address[] communityTokens) public userCommunities;
    mapping(address user => mapping(address communityToken => bool isMember)) public isCommunityMember;
    mapping(bytes32 productId => ProductBase) public productBaseInfo;
    mapping(bytes32 productId => Product) public productInfo;
    mapping(address user => mapping(address communityToken => bytes4[] userProducts)) public userProducts;
    mapping(address user => mapping(address communityToken => bytes4[] buyedProducts)) public userBuyedProducts;

    /////////////////////
    ////// Arrays  //////
    /////////////////////
    address[] public communityTokens;

    ////////////////
    //   Events  //
    ////////////////
    event ABTBoughtByUser(address indexed user, uint256 indexed amountABT);
    event CommunityCreated(
        string indexed communityName, address indexed communityCreator, address indexed communityToken
    );
    event JoinedCommunity(address indexed user, address indexed communityToken);
    event ProductSubmitted(bytes32 indexed productId, address indexed author, uint256 indexed stakeAmount);

    /////////////////
    //  Modifiers  //
    /////////////////

    modifier onlyDeployer() {
        require(msg.sender == creatorProtocol, "MainEngine: Only Deployer can call");
        _;
    }

    modifier productIsApprovedANDExists(bytes4 productId) {
        ProductBase storage tempProdBaseInfo = productBaseInfo[productId];
        if (!tempProdBaseInfo.exists) {
            revert MainEngine__ProductNotApproved();
        }
        if (!IVotingContract(votingContractAddr).isApproved(productId)) {
            revert MainEngine__ProductNotApproved();
        }
        _;
    }

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
        // Minimum amount to create a community is 1000 ABT
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

    /*
     * @notice Function to join a community
     * @param tokenAddress address of the community token
     */

    function joinCommunity(address tokenAddress) external {
        // Join the community
        if (communityInfo[tokenAddress].communityCreator == address(0)) {
            revert MainEngine__JoinCommunityFailed();
        }
        if (isCommunityMember[msg.sender][tokenAddress]) {
            revert MainEngine__AlreadyAMember();
        }
        communityInfo[tokenAddress].totalMembers += 1;
        isCommunityMember[msg.sender][tokenAddress] = true;
        userCommunities[msg.sender].push(tokenAddress);

        emit JoinedCommunity(msg.sender, tokenAddress);
    }

    /**
     * @notice Function to buy ArtBlock token by sending ether
     * @param to address of the user who is buying the ArtBlock token
     * @param amount number of ArtBlock tokens to buy
     */
    function buyArtBlockToken(address to, uint256 amount) public payable {
        // ToDo : Need to change the tokenRate through GoveranceContract
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

    /**
     * @notice Function to buy community token by sending ArtBlock token
     * @param to address of the user who is buying the community token
     * @param amount number of ArtBlock tokens to buy the community token
     * @param communityToken address of the community token
     */
    function buyCommunityToken(address to, uint256 amount, address communityToken) public payable {
        if (artBlockToken.balanceOf(to) < amount) {
            // ToDo : Need to change the tokenRate through GoveranceContract
            revert MainEngine__InSufficientAmount();
        }
        artBlockToken.burnFrom(to, amount);
        CustomERC20Token(communityToken).mint(to, amount);
    }

    function submitNewProduct(string memory metadata, address commToken, uint256 price, bool isExclusive) external {
        if (communityInfo[commToken].communityCreator != msg.sender) {
            revert MainEngine__UnAuthorised();
        }

        // Generate a unique product ID using keccak256
        bytes4 productId = bytes4(keccak256(abi.encodePacked(msg.sender, block.timestamp, metadata, price, commToken)));

        require(!productBaseInfo[productId].exists, "Product already exists");

        uint256 stakedAmount = getStackAmountFromPrice(price, isExclusive);

        CustomERC20Token(commToken).transferFrom(msg.sender, address(this), stakedAmount);

        productBaseInfo[productId] = ProductBase({
            stakeAmount: stakedAmount,
            stackReturned: false,
            upvotes: 0,
            downvotes: 0,
            approved: false,
            exists: true,
            productSubmittedTime: block.timestamp
        });

        productInfo[productId] = Product({
            metadata: metadata,
            price: price,
            isListedForResell: false,
            isListedOnMarketPlace: false,
            author: msg.sender,
            currentOwner: msg.sender,
            currentCommunity: commToken
        });

        userProducts[msg.sender][commToken].push(productId);

        emit ProductSubmitted(productId, msg.sender, price);
    }

    function checkProductApproval(bytes4 productId) external returns (bool status) {
        status = IVotingContract(votingContractAddr).isApproved(productId);
        if (status) {
            ProductBase storage tempProdInfo = productBaseInfo[productId];
            if (!tempProdInfo.stackReturned) {
                tempProdInfo.stackReturned = true;
                CustomERC20Token(productInfo[productId].currentCommunity).transfer(
                    productInfo[productId].currentOwner, productBaseInfo[productId].stakeAmount
                );
                tempProdInfo.approved = true;
            }
        } else {
            if (
                productBaseInfo[productId].productSubmittedTime
                    + IVotingContract(votingContractAddr).getVotingDuration() < block.timestamp
            ) {
                // If the product is not approved within 7 days then the product is not approved
                revert MainEngine__ProductNotApproved();
            } else {
                IVotingContract(votingContractAddr).calculateVotingResult(productId);
            }
        }
    }

    /////////////////////////////
    /////  Internal Functions  //
    /////////////////////////////

    function getStackAmountFromPrice(uint256 price, bool isExclusive) internal view returns (uint256) {
        if (isExclusive) {
            return (price * 3 * PRECESSION) / 10; // If the product is exclusive then the stake amount is 30% of the
                // price
        }
        return (price * 15 * PRECESSION) / 100; // If the product is not exclusive then the stake amount is 15% of the
            // price
    }

    /////////////////////////////
    /////  Setter Functions  ////
    /////////////////////////////
    function setVotingContract(address votingContract) external onlyDeployer {
        votingContractAddr = votingContract;
    }

    function setGovernanceContract(address governanceContract) external onlyDeployer {
        govContract = governanceContract;
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

    function isCommunityMembr(address user, address communityToken) public view returns (bool) {
        return isCommunityMember[user][communityToken];
    }

    function getProductBaseInfo(bytes4 productId) external view returns (ProductBase memory) {
        return productBaseInfo[productId];
    }
}
