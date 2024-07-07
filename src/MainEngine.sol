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

import { console } from "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import { CustomERC20Token } from "./CustomERC20Token.sol";

interface IVotingContract {
    function isApproved(bytes4 productId) external view returns (bool);
    function calculateVotingResult(bytes4 productId) external;
    function getVotingDuration() external pure returns (uint256);
}

interface IArtBlockNFT {
    function safeMint(address to, string memory uri, bytes4 productId) external;
    function safeTransfer(address from, address to, uint256 tokenId) external;
    function getTokenId(bytes4 tokenId) external view returns (uint256);
}

/**
 * @title MainEngine
 * @notice Manages community creation, token minting, and product submission and approval processes.
 * @dev Integrates with CustomERC20Token and IVotingContract.
 */
contract MainEngine {
    using Math for uint256;

    ///////////////
    /// Errors ////
    ///////////////

    /// @notice Error indicating that a transfer has failed.
    error MainEngine__TransferFailed();
    /// @notice Error indicating that the provided amount is insufficient.
    error MainEngine__InSufficientAmount();
    /// @notice Error indicating that joining the community has failed.
    error MainEngine__JoinCommunityFailed();
    /// @notice Error indicating that the user is already a member of the community.
    error MainEngine__AlreadyAMember();
    /// @notice Error indicating that the product already exists.
    error MainEngine__ProductAlreadyExists();
    /// @notice Error indicating that the product is not existing.
    error MainEngine__ProductNotExisting();
    /// @notice Error indicating that the product is not approved.
    error MainEngine__ProductNotApproved();
    /// @notice Error indicating that the voting is ongoing.
    error MainEngine__VotingOngoing();
    /// @notice Error indicating that the user is unauthorized to perform an action.
    error MainEngine__UnAuthorised();
    /// @notice Error indicating that the user is unauthorized to perform an action.
    error MainEngine__ProductIsInMarketPlace();
    /// @notice Error indicating that the user has not met the threshold.
    error MainEngine__UserActivityPointIsLOW();

    /////////////////////////
    //   State Variables  //
    ////////////////////////

    /// @notice Address of the creator protocol.
    address private immutable creatorProtocol;
    /// @notice Instance of the CustomERC20 Token.
    CustomERC20Token private immutable artBlockToken;
    /// @notice Address of the governance contract.
    address private govContract;
    /// @notice Address of the voting contract.
    address private votingContractAddr;
    /// @notice Address of the ArtBlock NFT contract.
    address private artBlockNFTContract;
    /// @notice Precision value for token calculations.
    uint256 private PRECESSION = 10 ** 18;
    /// @notice Minimum amount to create a community.
    uint256 private constant COMMUNITY_CREATION_FEE = 1000;
    /// @notice Rate of the platform native token.
    uint256 public baseRate = 0.5 ether;
    /// @notice Exponent value for token calculations.
    uint256 public exponent = 1;
    /// @notice Rate of the community token.
    uint256 public baseCommunityTokenRate = 0.2 ether; // 1 ArtBlock token equals 5 community tokens

    //////////////////////
    ////// Structs  //////
    //////////////////////

    /// @notice Struct to store community information.
    struct CommunityInfo {
        string communityName;
        string communityDescription;
        string tokenName;
        string tokenSymbol;
        address communityCreator;
        uint256 totalMembers;
    }

    /// @notice Struct to store basic product information.
    struct ProductBase {
        uint256 stakeAmount;
        bool stackReturned;
        uint256 upvotes;
        uint256 downvotes;
        uint256 productSubmittedTime;
        bool approved;
        bool exists;
        bool isExclusive;
    }

    /// @notice Struct to store detailed product information.
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

    /// @notice Mapping from community token address to community information.
    mapping(address => CommunityInfo) public communityInfo;
    /// @notice Mapping from community creator address to a list of their communities.
    mapping(address => CommunityInfo[]) public creatorCommunities;
    /// @notice Mapping from user address to a list of community tokens they are part of.
    mapping(address => address[]) public userCommunities;
    /// @notice Mapping from user address and community token address to membership status.
    mapping(address => mapping(address => bool)) public isCommunityMember;
    /// @notice Mapping from product ID to basic product information.
    mapping(bytes32 => ProductBase) public productBaseInfo;
    /// @notice Mapping from product ID to detailed product information.
    mapping(bytes32 => Product) public productInfo;
    /// @notice Mapping from user address and community token address to a list of their products.
    mapping(address => mapping(address => bytes4[])) public userProducts;
    /// @notice Mapping from user address and community token address to a list of products they have bought.
    mapping(address => mapping(address => bytes4[])) public userBuyedProducts;
    /// @notice Mapping from user address and community token address to a count activity points.
    mapping(address => mapping(address => uint256)) public userActivityPoints;
    /// @notice Mapping from community token address to a community activity points.
    mapping(address => uint256) public communityActivityPoints;

    /////////////////////
    ////// Arrays  //////
    /////////////////////

    /// @notice List of community token addresses.
    address[] public communityTokens;

    ////////////////
    //   Events  //
    ////////////////

    /// @notice Event emitted when a user buys ArtBlock tokens.
    /// @param user The address of the user who bought the tokens.
    /// @param amountABT The amount of tokens bought.
    event ABTBoughtByUser(address indexed user, uint256 indexed amountABT);

    /// @notice Event emitted when a community is created.
    /// @param communityName The name of the community.
    /// @param communityCreator The address of the community creator.
    /// @param communityToken The address of the community token.
    event CommunityCreated(
        string indexed communityName, address indexed communityCreator, address indexed communityToken
    );

    /// @notice Event emitted when a user joins a community.
    /// @param user The address of the user.
    /// @param communityToken The address of the community token.
    event JoinedCommunity(address indexed user, address indexed communityToken);

    /// @notice Event emitted when a product is submitted.
    /// @param productId The ID of the product.
    /// @param author The address of the product author.
    /// @param stakeAmount The amount staked for the product.
    event ProductSubmitted(bytes32 indexed productId, address indexed author, uint256 indexed stakeAmount);

    /////////////////
    //  Modifiers  //
    /////////////////

    /// @notice Modifier to restrict access to functions to only the deployer.
    modifier onlyDeployer() {
        require(msg.sender == creatorProtocol, "MainEngine: Only Deployer can call");
        _;
    }

    /// @notice Modifier to ensure that the product is approved and exists.
    /// @param productId The ID of the product.
    modifier productIsApprovedANDExists(bytes4 productId) {
        ProductBase memory tempProdBaseInfo = productBaseInfo[productId];
        if (!tempProdBaseInfo.exists) {
            revert MainEngine__ProductNotExisting();
        }
        if (!IVotingContract(votingContractAddr).isApproved(productId)) {
            revert MainEngine__ProductNotApproved();
        }
        _;
    }

    modifier productExistsAndHasListedTimePassed(bytes4 productId) {
        if (!productBaseInfo[productId].exists) {
            revert MainEngine__ProductNotExisting();
        }
        if (
            productBaseInfo[productId].productSubmittedTime + IVotingContract(votingContractAddr).getVotingDuration()
                > block.timestamp
        ) {
            revert MainEngine__VotingOngoing();
        }
        _;
    }

    modifier isOwner(bytes4 productId) {
        if (productInfo[productId].currentOwner != msg.sender) {
            revert MainEngine__UnAuthorised();
        }
        _;
    }

    modifier hasEnoughBalanceToBuy(bytes4 productId, address communityToken) {
        if (CustomERC20Token(communityToken).balanceOf(msg.sender) < productInfo[productId].price) {
            revert MainEngine__InSufficientAmount();
        }
        _;
    }

    modifier canPostProductToSell(bytes4 productId) {
        if (productInfo[productId].currentOwner != msg.sender) {
            revert MainEngine__UnAuthorised();
        }
        if (productInfo[productId].isListedOnMarketPlace) {
            revert MainEngine__ProductIsInMarketPlace();
        }
        if (productInfo[productId].currentCommunity != address(0)) {
            revert MainEngine__ProductIsInMarketPlace();
        }
        _;
    }

    /////////////////
    //  Functions  //
    /////////////////

    /**
     * @notice Constructor to initialize the MainEngine contract.
     * @dev Sets the creator protocol to the deployer's address and creates a new ArtBlockToken instance.
     */
    constructor() {
        creatorProtocol = msg.sender;
        artBlockToken = new CustomERC20Token("ARTBLOCKTOKEN", "ABT", address(this));
    }

    //////////////////////////
    //  External Functions  //
    //////////////////////////

    /**
     * @notice Function to create a new community.
     * @param communityName The name of the community.
     * @param communityDescription The description of the community.
     * @param tokenName The name of the community token.
     * @param tokenSymbol The symbol of the community token.
     * @param communityCreator The address of the creator of the community.
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
        if (artBlockToken.balanceOf(communityCreator) < COMMUNITY_CREATION_FEE * PRECESSION) {
            revert MainEngine__InSufficientAmount();
        }
        artBlockToken.transferFrom(communityCreator, address(this), COMMUNITY_CREATION_FEE * PRECESSION);
        CustomERC20Token communityToken = new CustomERC20Token(tokenName, tokenSymbol, communityCreator);
        communityTokens.push(address(communityToken));
        CommunityInfo memory newCommunity =
            CommunityInfo(communityName, communityDescription, tokenName, tokenSymbol, communityCreator, 1);
        communityInfo[address(communityToken)] = newCommunity;
        creatorCommunities[communityCreator].push(newCommunity);
        emit CommunityCreated(communityName, communityCreator, address(communityToken));
    }

    /**
     * @notice Function to join a community.
     * @param tokenAddress The address of the community token.
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
     * @notice Function to buy ArtBlock tokens by sending ether.
     * @param to The address of the user who is buying the ArtBlock tokens.
     * @param amount The number of ArtBlock tokens to buy.
     */
    function buyArtBlockToken(address to, uint256 amount) public payable {
        require(amount > 0, "Amount must be greater than zero");
        // Implemented bonding curve
        uint256 currentSupply = artBlockToken.totalSupply() == 0 ? 1 : artBlockToken.totalSupply();
        uint256 pricePerToken = baseRate * (currentSupply ** exponent); // overflows or underflow can happen

        uint256 totalCost = pricePerToken * amount;

        // check if the user has sent the specified amount of ether to buy the ABT token
        console.log("Token Rate: ", pricePerToken);
        console.log("Total Cost: ", totalCost);
        console.log("msg.value: ", msg.value);

        if (totalCost != msg.value) {
            revert MainEngine__InSufficientAmount();
        }
        // Mint tokens before transferring Ether to avoid reentrancy issues
        artBlockToken.mint(to, amount * PRECESSION);

        (bool success,) = creatorProtocol.call{ value: totalCost }("");
        // check if the transfer of ABT is successful
        if (!success) {
            revert MainEngine__TransferFailed();
        }

        emit ABTBoughtByUser(to, amount);
    }

    // /**
    //  * @notice Function to buy community tokens by sending ArtBlock tokens.
    //  * @param to The address of the user who is buying the community tokens.
    //  * @param amount The number of ArtBlock tokens to buy the community tokens.
    //  * @param communityToken The address of the community token.
    //  */
    // function buyCommunityToken(address to, uint256 amount, address communityToken) public payable {
    //     if (artBlockToken.balanceOf(to) < amount) {
    //         // ToDo : Need to change the tokenRate through GovernanceContract
    //         revert MainEngine__InSufficientAmount();
    //     }
    //     artBlockToken.burnFrom(to, amount);
    //     CustomERC20Token(communityToken).mint(to, amount * PRECESSION);
    // }

    function buyCommunityToken(address to, uint256 amount, address communityToken) public {
        uint256 communityPoints = communityActivityPoints[communityToken];
        uint256 userPoints = userActivityPoints[to][communityToken];
        uint256 rateAdjustment = calculateRateAdjustment(communityPoints, userPoints);

        uint256 tokenRate = baseCommunityTokenRate * rateAdjustment / 1 ether; // Adjust the rate proportionally
        uint256 cost = amount * tokenRate / 1 ether; // Adjust for Solidity's lack of floating point

        console.log("Cost: ", cost);
        console.log("User balance: ", artBlockToken.balanceOf(to));

        if (artBlockToken.balanceOf(to) < cost) {
            revert MainEngine__InSufficientAmount();
        }

        artBlockToken.transfer(address(this), cost);
        CustomERC20Token(communityToken).mint(to, amount * PRECESSION);
    }

    /**
     * @notice Function to submit a new product.
     * @param metadata The metadata of the product.
     * @param commToken The address of the community token.
     * @param price The price of the product.
     * @param isExclusive Whether the product is exclusive.
     */
    function submitNewProduct(string memory metadata, address commToken, uint256 price, bool isExclusive) external {
        if (communityInfo[commToken].communityCreator != msg.sender) {
            revert MainEngine__UnAuthorised();
        }

        // Generate a unique product ID using keccak256
        bytes4 productId = bytes4(keccak256(abi.encodePacked(msg.sender, block.timestamp, metadata, price, commToken)));

        require(!productBaseInfo[productId].exists, "Product already exists");

        uint256 stakedAmount = getStackAmountFromPrice(price, isExclusive);

        console.log("Products Price: ", price);
        console.log("Staked Amount: ", stakedAmount);

        CustomERC20Token(commToken).transferFrom(msg.sender, address(this), stakedAmount);

        productBaseInfo[productId] = ProductBase({
            stakeAmount: stakedAmount,
            stackReturned: false,
            upvotes: 0,
            downvotes: 0,
            approved: false,
            exists: true,
            isExclusive: isExclusive,
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

    /**
     * @notice Checks if the product is approved, handles stake return
     * @param productId The ID of the product to check.
     * @return bool indicating if the product is approved.
     */
    function checkProductApproval(bytes4 productId)
        external
        productExistsAndHasListedTimePassed(productId)
        returns (bool)
    {
        bool isApproved = IVotingContract(votingContractAddr).isApproved(productId);

        if (!productBaseInfo[productId].stackReturned) {
            if (isApproved) {
                productBaseInfo[productId].approved = true;
                returnStake(productId);
            } else {
                returnStakeHalf(productId);
            }
            productBaseInfo[productId].stackReturned = true;
        }

        return isApproved;
    }

    /**
     * @notice Returns the stake for the given product.
     * @param productId The ID of the product for which to return the stake.
     */
    function returnStake(bytes4 productId) private {
        CustomERC20Token(productInfo[productId].currentCommunity).transfer(
            productInfo[productId].currentOwner, productBaseInfo[productId].stakeAmount
        );
    }

    /**
     * @notice Returns the half stake for the given product if not approved.
     * @param productId The ID of the product for which to return the stake.
     */
    function returnStakeHalf(bytes4 productId) private {
        uint256 halfStakeValue = (productBaseInfo[productId].stakeAmount * 50) / 100;
        CustomERC20Token(productInfo[productId].currentCommunity).transfer(
            productInfo[productId].currentOwner, halfStakeValue
        );
    }

    /**
     * @notice Checks if the voting result can be calculated for the given product.
     * @param productId The ID of the product to check.
     * @return bool indicating if the voting result can be calculated.
     */
    function canCalculateVotingResult(bytes4 productId) public view returns (bool) {
        ProductBase memory productBase = productBaseInfo[productId];
        return !productBase.approved
            && (
                productBase.productSubmittedTime + IVotingContract(votingContractAddr).getVotingDuration() < block.timestamp
            );
    }

    /**
     * @notice Function to list the product in the marketplace.
     * @param productId The ID of the product for which to calculate the voting result.
     * @param commToken The address of the community token.
     */
    function listProductToMarketPlace(
        bytes4 productId,
        address commToken
    )
        public
        productExistsAndHasListedTimePassed(productId)
        productIsApprovedANDExists(productId)
        isOwner(productId)
    {
        Product memory product = productInfo[productId];
        if (product.currentOwner != product.author) {
            if (productBaseInfo[productId].isExclusive) {
                IArtBlockNFT(artBlockNFTContract).safeMint(msg.sender, productInfo[productId].metadata, productId);
            }
            productInfo[productId].isListedOnMarketPlace = true;
            productInfo[productId].currentCommunity = commToken;
        }
    }

    /**
     * @notice Function to buy a product.
     * @param productId  The ID of the product to buy.
     * @param communityToken  The address of the community token.
     */
    function buyProduct(
        bytes4 productId,
        address communityToken
    )
        public
        productIsApprovedANDExists(productId)
        hasEnoughBalanceToBuy(productId, communityToken)
    {
        Product memory product = productInfo[productId];
        if (product.isListedOnMarketPlace && isCommunityMember[msg.sender][communityToken]) {
            if (product.currentOwner != product.author) {
                CustomERC20Token(communityToken).transferFrom(msg.sender, product.author, (product.price * 3) / 100);
                CustomERC20Token(communityToken).transferFrom(
                    msg.sender, product.currentOwner, (product.price * 97) / 100
                );
            } else {
                CustomERC20Token(communityToken).transferFrom(msg.sender, product.currentOwner, product.price);
            }

            if (productBaseInfo[productId].isExclusive) {
                IArtBlockNFT(artBlockNFTContract).safeTransfer(
                    product.currentOwner, msg.sender, IArtBlockNFT(artBlockNFTContract).getTokenId(productId)
                );
            }

            productInfo[productId].currentOwner = msg.sender;
            productInfo[productId].currentCommunity = address(0);
            productInfo[productId].isListedOnMarketPlace = false;

            userBuyedProducts[msg.sender][communityToken].push(productId);
            increasePoints(msg.sender, communityToken);
        }
    }

    /**
     * @param productId The ID of the product to vote for.
     * @param price     The price of the product.
     * @param community The address of the community token.
     */
    function sellProdToComm(
        bytes4 productId,
        uint256 price,
        address community
    )
        external
        productIsApprovedANDExists(productId)
        canPostProductToSell(productId)
        isOwner(productId)
    {
        if (getUserActivityPoints(msg.sender, community) < 10) {
            revert MainEngine__UserActivityPointIsLOW();
        }

        productInfo[productId].price = price;
        // transfer 3% of product price to the community creator
        CustomERC20Token(community).transfer(communityInfo[community].communityCreator, (price * 3) / 100);
        productInfo[productId].isListedOnMarketPlace = true;
        productInfo[productId].currentCommunity = community;

        // increase activity points
        increasePoints(msg.sender, community);
    }

    /////////////////////////////
    /////  Internal Functions  //
    /////////////////////////////

    /**
     * @notice Internal function to calculate the stake amount from the price.
     * @param price The price of the product.
     * @param isExclusive Whether the product is exclusive.
     * @return The calculated stake amount.
     */
    function getStackAmountFromPrice(uint256 price, bool isExclusive) internal view returns (uint256) {
        if (isExclusive) {
            return (price * 3 * PRECESSION) / 10; // If the product is exclusive then the stake amount is 30% of the
                // price
        } else {
            return (price * 15 * PRECESSION) / 100; // If the product is not exclusive then the stake amount is 15% of
                // the
                // price
        }
    }

    /**
     * @notice Internal function to increase the activity points.
     * @param user The address of the user.
     * @param communityToken The address of the community token.
     */
    function increasePoints(address user, address communityToken) internal {
        userActivityPoints[user][communityToken] += 1;
        communityActivityPoints[communityToken] += 1;
    }

    /**
     * @notice Function to calculate the rate adjustment based on the community and user points.
     * @param communityPoints community points
     * @param userPoints use engagement points
     */
    function calculateRateAdjustment(uint256 communityPoints, uint256 userPoints) internal pure returns (uint256) {
        uint256 rateIncrease = communityPoints / 1000; // Example: rate increases by 1% for every 1000 points
        uint256 userDiscount = userPoints / 100; // Example: 1% discount for every 100 points
        uint256 adjustment = 1 ether + (rateIncrease * 1 ether / 100) - (userDiscount * 1 ether / 100);

        if (adjustment < 1 ether) {
            return 1 ether; // Ensure rate never goes below 1 ether
        }
        return adjustment;
    }

    /////////////////////////////
    /////  Setter Functions  ////
    /////////////////////////////

    /**
     * @notice Function to set the voting contract address.
     * @param votingContract The address of the voting contract.
     */
    function setVotingContract(address votingContract) external onlyDeployer {
        votingContractAddr = votingContract;
    }

    /**
     * @notice Function to set the governance contract address.
     * @param governanceContract The address of the governance contract.
     */
    function setGovernanceContract(address governanceContract) external onlyDeployer {
        govContract = governanceContract;
    }

    /**
     * @notice Function to set the NFT contract address.
     * @param nftContract The address of the NFT contract.
     */
    function setNFTContract(address nftContract) external onlyDeployer {
        artBlockNFTContract = nftContract;
    }

    /////////////////////////////
    //  view & pure Functions  //
    /////////////////////////////

    /**
     * @notice Function to get the ArtBlock token address.
     * @return The address of the ArtBlock token.
     */
    function getTokenAddress() public view returns (address) {
        return address(artBlockToken);
    }

    /**
     * @notice Function to get the creator protocol address.
     * @return The address of the creator protocol.
     */
    function getCreatorProtocol() public view returns (address) {
        return creatorProtocol;
    }

    /**
     * @notice Function to check if a user is a member of a community.
     * @param user The address of the user.
     * @param communityToken The address of the community token.
     * @return Whether the user is a member of the community.
     */
    function isCommunityMembr(address user, address communityToken) public view returns (bool) {
        return isCommunityMember[user][communityToken];
    }

    /**
     * @notice Function to get the basic product information.
     * @param productId The ID of the product.
     * @return The basic product information.
     */
    function getProductBaseInfo(bytes4 productId) external view returns (ProductBase memory) {
        return productBaseInfo[productId];
    }

    function getTotalMemberOfCommunity(address communityToken) public view returns (uint256) {
        return communityInfo[communityToken].totalMembers;
    }

    function getUserActivityPoints(address user, address communityToken) public view returns (uint256) {
        return userActivityPoints[user][communityToken];
    }

    function getCommunityActivityPoints(address communityToken) public view returns (uint256) {
        return communityActivityPoints[communityToken];
    }

    function getArtBlockRate() public view returns (uint256 pricePerToken) {
        uint256 currentSupply = artBlockToken.totalSupply() == 0 ? 1 : artBlockToken.totalSupply();
        console.log("comes here (before)");
        pricePerToken = baseRate * (currentSupply ** exponent);
        console.log("comes here (after)", pricePerToken);
    }
}
