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

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

    error MainEngine__TransferFailed();
    error MainEngine__InSufficientAmount();
    error MainEngine__JoinCommunityFailed();
    error MainEngine__AlreadyAMember();
    error MainEngine__ProductAlreadyExists();
    error MainEngine__ProductNotExisting();
    error MainEngine__ProductNotApproved();
    error MainEngine__VotingOngoing();
    error MainEngine__UnAuthorised();
    error MainEngine__ProductIsInMarketPlace();
    error MainEngine__UserActivityPointIsLOW();

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    ////////////////////////////////////////////////////////////*/
    address private immutable creatorProtocol;

    CustomERC20Token private immutable artBlockToken;

    address private govContract;
    address private votingContractAddr;
    address private artBlockNFTContract;
    uint256 private PRECESSION = 10 ** 18;
    uint256 private constant COMMUNITY_CREATION_FEE = 1000;
    uint256 public baseRate = 0.5 ether;
    uint256 public exponent = 1;
    uint256 public BASE_COMMUNITY_TOKEN_RATE = 0.2 ether; // 0.2 * 1e18

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/

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
        uint256 productSubmittedTime;
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
        address originCommunity;
    }

    /*//////////////////////////////////////////////////////////////
                                MAPPINGS
    //////////////////////////////////////////////////////////////*/

    mapping(address communityToken => CommunityInfo communityInformation) public communityInfo;
    mapping(address creatorAddress => CommunityInfo[] listOfCommunities) public creatorCommunities;
    mapping(address userAddress => address[]) public userCommunities;
    mapping(address userAddress => mapping(address communityToken => bool)) public isCommunityMember;
    mapping(bytes4 productID => ProductBase productBasicInfo) public productBaseInfo;
    mapping(bytes4 productID => Product productDetailedInfo) public productInfo;
    mapping(address userAddress => mapping(address communityToken => bytes4[] productIDList)) public userProducts;
    mapping(address userAddress => mapping(address communityToken => bytes4[] productIDList)) public userBuyedProducts;
    mapping(address userAddress => mapping(address communityToken => uint256 points)) public userActivityPoints;
    mapping(address communityToken => uint256 communityPoints) public communityActivityPoints;

    /*//////////////////////////////////////////////////////////////
                                 ARRAYS
    //////////////////////////////////////////////////////////////*/

    address[] public communityTokens;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event ABTBoughtByUser(address indexed user, uint256 indexed amountABT);

    event CommunityCreated(
        string indexed communityName, address indexed communityCreator, address indexed communityToken
    );

    event JoinedCommunity(address indexed user, address indexed communityToken);

    event ProductSubmitted(bytes4 indexed productId, address indexed author, uint256 indexed stakeAmount);

    event ProductApproved(bytes4 indexed productId, address indexed communityToken);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /// @notice Modifier to restrict access to functions to only the deployer.
    modifier onlyDeployer() {
        require(msg.sender == creatorProtocol, "MainEngine: Only Deployer can call");
        _;
    }

    /// @notice Modifier to ensure that the product exists.
    modifier productExists(bytes4 productId) {
        if (!productBaseInfo[productId].exists) {
            revert MainEngine__ProductNotExisting();
        }
        _;
    }

    /// @notice Modifier to ensure that the product is approved.
    modifier productIsApproved(bytes4 productId) {
        if (!IVotingContract(votingContractAddr).isApproved(productId)) {
            revert MainEngine__ProductNotApproved();
        }
        _;
    }

    /// @notice Modifier to ensure that the voting time has passed.
    modifier votingTimePassed(bytes4 productId) {
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

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Constructor to initialize the MainEngine contract.
     * @dev Sets the creator protocol to the deployer's address and creates a new ArtBlockToken instance.
     */
    constructor() {
        creatorProtocol = msg.sender;
        artBlockToken = new CustomERC20Token("ARTBLOCKTOKEN", "ABT", address(this));
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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
        uint256 pricePerToken = getArtBlockRate();
        uint256 totalCost = pricePerToken * amount;
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

    /**
     * @notice Function to buy community tokens by sending ArtBlock tokens.
     * @param to The address of the user who is buying the community tokens.
     * @param amount The number of ArtBlock tokens to buy the community tokens.
     * @param communityToken The address of the community token.
     */
    function buyCommunityToken(address to, uint256 amount, address communityToken) public {
        uint256 cost = getCommunityTokenCost(to, amount, communityToken);
        if (artBlockToken.balanceOf(to) < cost) {
            revert MainEngine__InSufficientAmount();
        }

        artBlockToken.transferFrom(to, address(this), cost * PRECESSION);
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
        console.log("Community Creator: ", communityInfo[commToken].communityCreator);
        console.log("Sender: ", msg.sender);

        if (communityInfo[commToken].communityCreator != msg.sender) {
            revert MainEngine__UnAuthorised();
        }

        // Generate a unique product ID using keccak256
        bytes4 productId = bytes4(keccak256(abi.encodePacked(msg.sender, block.timestamp, metadata, price, commToken)));

        require(!productBaseInfo[productId].exists, "Product already exists");

        uint256 stakedAmount = getStackAmountFromPrice(price, isExclusive);

        // @error ERC20InsufficientAllowance
        // console.log("MainEngine::StacekdAMount: ", stakedAmount);
        // console.log("MainEngine::Custom token balance: ", CustomERC20Token(commToken).balanceOf(msg.sender));
        // console.log(
        //     "MainEngine::Custom token Allowance", CustomERC20Token(commToken).allowance(msg.sender, address(this))
        // );
        CustomERC20Token(commToken).transferFrom(msg.sender, address(this), stakedAmount);

        productBaseInfo[productId] = ProductBase({
            stakeAmount: stakedAmount,
            stackReturned: false,
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
            currentOwner: address(0),
            currentCommunity: commToken,
            originCommunity: commToken
        });

        userProducts[msg.sender][commToken].push(productId);

        emit ProductSubmitted(productId, msg.sender, price);
    }

    /**
     * @notice Checks if the product is approved, handles stake return
     * @param productId The ID of the product to check.
     * @return bool indicating if the product is approved.
     */
    function checkProductApprovalStatus(bytes4 productId) external view returns (bool) {
        bool isApproved = IVotingContract(votingContractAddr).isApproved(productId);
        return isApproved;
    }

    /**
     * @notice Function to return the stacked amount of a product.
     * @param productId The ID of the product
     */
    // @q shouldn't the creator of the product be able to call the function ?
    function returnStackedAmount(bytes4 productId) external votingTimePassed(productId) {
        bool isApproved = IVotingContract(votingContractAddr).isApproved(productId);
        if (!productBaseInfo[productId].stackReturned) {
            if (isApproved) {
                emit ProductApproved(productId, productInfo[productId].currentCommunity);
                returnStake(productId);
            } else {
                returnStakeHalf(productId);
            }
            productBaseInfo[productId].stackReturned = true;
        }
    }

    /**
     * @notice Returns the stake for the given product.
     * @param productId The ID of the product for which to return the stake.
     */
    function returnStake(bytes4 productId) private {
        CustomERC20Token(productInfo[productId].currentCommunity).transfer(
            productInfo[productId].author, productBaseInfo[productId].stakeAmount
        );
    }

    /**
     * @notice Returns the half stake for the given product if not approved.
     * @param productId The ID of the product for which to return the stake.
     */
    function returnStakeHalf(bytes4 productId) private {
        uint256 halfStakeValue = (productBaseInfo[productId].stakeAmount * 50) / 100;
        CustomERC20Token(productInfo[productId].currentCommunity).transfer(
            productInfo[productId].author, halfStakeValue
        );
    }

    /**
     * @notice Checks if the voting result can be calculated for the given product.
     * @param productId The ID of the product to check.
     * @return bool indicating if the voting result can be calculated.
     */
    function canCalculateVotingResult(bytes4 productId) public view returns (bool) {
        ProductBase memory productBase = productBaseInfo[productId];
        return
            productBase.productSubmittedTime + IVotingContract(votingContractAddr).getVotingDuration() < block.timestamp;
    }

    /**
     * @notice The author of the product can list the product after the product is approved by voting.
     * @param productId The ID of the product for which to calculate the voting result.
     * @param commToken The address of the community token.
     */
    function listProductToAuthorsCommunity(
        bytes4 productId,
        address commToken
    )
        public
        productExists(productId)
        productIsApproved(productId)
        votingTimePassed(productId)
    {
        if (productInfo[productId].author != msg.sender && getCommunityInfo(commToken).communityCreator != msg.sender) {
            revert MainEngine__UnAuthorised();
        }
        require(productBaseInfo[productId].stackReturned, "MainEngine__Stacked Amount is not returned");

        if (productBaseInfo[productId].isExclusive) {
            IArtBlockNFT(artBlockNFTContract).safeMint(msg.sender, productInfo[productId].metadata, productId);
        }
        productInfo[productId].isListedOnMarketPlace = true;
        productInfo[productId].currentCommunity = commToken;
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
        productExists(productId)
        productIsApproved(productId)
        hasEnoughBalanceToBuy(productId, communityToken)
    {
        Product memory product = productInfo[productId];

        if (product.isListedOnMarketPlace && isCommunityMember[msg.sender][communityToken]) {
            if (product.currentOwner != address(0)) {
                CustomERC20Token(communityToken).transferFrom(
                    msg.sender, product.author, (product.price * PRECESSION * 3) / 100
                );
                CustomERC20Token(communityToken).transferFrom(
                    msg.sender, product.currentOwner, (product.price * PRECESSION * 97) / 100
                );
            } else {
                CustomERC20Token(communityToken).transferFrom(msg.sender, product.author, product.price * PRECESSION);
            }
        }

        address fromUser = product.currentOwner == address(0) ? product.author : product.currentOwner;

        if (productBaseInfo[productId].isExclusive) {
            IArtBlockNFT(artBlockNFTContract).safeTransfer(
                fromUser, msg.sender, IArtBlockNFT(artBlockNFTContract).getTokenId(productId)
            );
        }

        productInfo[productId].currentOwner = msg.sender;
        productInfo[productId].currentCommunity = address(0);
        productInfo[productId].isListedOnMarketPlace = false;

        userBuyedProducts[msg.sender][communityToken].push(productId);
        increasePoints(msg.sender, communityToken, 10);
    }

    /**
     * @notice Function to list a product for selling to the community.
     * @param productId The ID of the product to vote for.
     * @param price     The price of the product.
     * @param community The address of the community token.
     */
    function listProductToOtherCommunityForSelling(
        bytes4 productId,
        uint256 price,
        address community
    )
        external
        productExists(productId)
        productIsApproved(productId)
        isOwner(productId)
    {
        if (communityInfo[community].communityCreator == msg.sender) {
            revert MainEngine__UnAuthorised();
        }

        if (productInfo[productId].isListedOnMarketPlace) {
            revert MainEngine__ProductIsInMarketPlace();
        }

        // @dis disabled for testing purpose

        // if (getUserActivityPoints(msg.sender, community) < 10) {
        //     revert MainEngine__UserActivityPointIsLOW();
        // }

        productInfo[productId].price = price;
        // transfer 10% of the price to the community creator
        CustomERC20Token(community).transferFrom(
            msg.sender, communityInfo[community].communityCreator, (price * PRECESSION) / 10
        );
        productInfo[productId].isListedOnMarketPlace = true;
        productInfo[productId].currentCommunity = community;

        // increase activity points
        increasePoints(msg.sender, community, 5);
    }

    /**
     * @notice user can list his purchased product to his community
     * @param productId ID of the product
     * @param price new price of the product
     * @param community the address of community/ community token
     */
    function listPurchasedProductToOwnCommunity(
        bytes4 productId,
        uint256 price,
        address community
    )
        external
        productExists(productId)
        productIsApproved(productId)
        isOwner(productId)
    {
        if (communityInfo[community].communityCreator != msg.sender) {
            revert MainEngine__UnAuthorised();
        }
        productInfo[productId].price = price;
        productInfo[productId].isListedOnMarketPlace = true;
        productInfo[productId].currentCommunity = community;
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

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
                // the price
        }
    }

    /**
     * @notice Internal function to increase the activity points.
     * @param user The address of the user.
     * @param communityToken The address of the community token.
     */
    function increasePoints(address user, address communityToken, uint16 points) internal {
        userActivityPoints[user][communityToken] += points;
        communityActivityPoints[communityToken] += points;
    }

    /**
     * @notice Function to calculate the rate adjustment based on the community and user points.
     * @param communityPoints community points
     * @param userPoints use engagement points
     */
    function calculateRateAdjustment(uint256 communityPoints, uint256 userPoints) internal view returns (uint256) {
        uint256 rateIncrease = (communityPoints * PRECESSION) / 1000; // 0.1% increase per 1000 points
        uint256 userDiscount = (userPoints * PRECESSION) / 100; // 1% discount per 100 points

        if (userDiscount > rateIncrease) {
            return PRECESSION; // Ensure rate never goes below 1 (100%)
        }

        return PRECESSION + rateIncrease - userDiscount;
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
        require(productBaseInfo[productId].exists, "Product does not exist");
        return productBaseInfo[productId];
    }

    function getProductDetailedInfo(bytes4 productId) external view returns (Product memory) {
        require(productBaseInfo[productId].exists, "Product does not exist");
        return productInfo[productId];
    }

    function getAllCommunities() external view returns (address[] memory) {
        return communityTokens;
    }

    function getCommunityInfo(address communityToken) public view returns (CommunityInfo memory) {
        return communityInfo[communityToken];
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

    function getCommunityCreationFee() public pure returns (uint256) {
        return COMMUNITY_CREATION_FEE;
    }

    function getArtBlockRate() public view returns (uint256 pricePerToken) {
        uint256 currentSupply = artBlockToken.totalSupply() == 0 ? 1 : artBlockToken.totalSupply() / PRECESSION;
        pricePerToken = baseRate + (currentSupply ** exponent);
    }

    function getProductStatus(bytes4 productId) external view returns (bool) {
        return productBaseInfo[productId].exists;
    }

    function getProductSubmittedTime(bytes4 productId) external view returns (uint256) {
        return productBaseInfo[productId].productSubmittedTime;
    }

    function getCommunityTokenCost(address to, uint256 amount, address communityToken) public view returns (uint256) {
        uint256 communityPoints = communityActivityPoints[communityToken];
        uint256 userPoints = userActivityPoints[to][communityToken];
        uint256 rateAdjustment = calculateRateAdjustment(communityPoints, userPoints);

        uint256 adjustedRate = (BASE_COMMUNITY_TOKEN_RATE * rateAdjustment) / PRECESSION; // Adjust the rate
            // proportionally
        uint256 cost = (amount * adjustedRate) / PRECESSION; // Adjust for Solidity's lack of floating point

        return cost;
    }
}
