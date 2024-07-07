# ArtBlockForge Platform - Smart Contracts

Welcome to the ArtBlockForge Platform! This README provides an overview of the smart contracts used in the ArtBlockForge Platform, a decentralized creator-based community focusing on various forms of art. These communities operate as Decentralized Autonomous Organizations (DAOs) with no centralized power dictating their operations. Below, you'll find detailed information about each smart contract, their purpose, and how they interact within the ArtBlockForge ecosystem.

## Key Features

### Tokenomics
- **ArtBlock Token (ABT):** Native ERC-20 token used across the platform.
- **Dynamic Pricing:** Utilizes a bonding curve for dynamic pricing of ABT tokens. The price per token is calculated based on the current supply using the formula

```
exponent = 1; // Exponent for the bonding curve
pricePerToken = baseRate * (currentSupply ** exponent);
totalCost = pricePerToken * amount;
```



### Community Creation
- **Fee-Based Community Formation:** Users can initiate their own communities by spending a fee of 1000 ABT. This fee helps maintain the quality of the platform by preventing spam and serves as an investment into the platform’s ecosystem.
- **Customizable Community Attributes:** Community creators have the flexibility to define the name of their community token, governance rules, and other unique characteristics, fostering diverse and niche communities.

### Community Participation
- **Joining Communities:** Users can become part of any community by purchasing its specific tokens, which are required for participation in voting and governance.
- **Community Tokens:** Initially pegged at 1 ABT = 5 community tokens. The token rate dynamically adjusts based on community activity and user points—increasing by 1% for every 1000 community points and offering a 1% discount for every 100 user points, promoting an active and engaged community environment.

### Marketplace and Voting
- **Product Listings:** Products can be tagged as general or exclusive. General products require a 15% staking of their value in ABT by the creator, whereas exclusive products require a 30% stake.
- **Voting Mechanism:** Employs a weighted voting system where 60% of a user’s voting weight comes from community tokens and 40% from ABT, ensuring that those most invested in the community have a significant say.
- **Governance Outcomes:** If a product is approved, the full staked amount is returned to the creator. If not approved, 50% of the stake is returned to the creator and 50% is forfeited to support platform operations.

### Economic Model
- **Exclusive Products:** Minted as NFTs, sold in the marketplace. This process ensures the uniqueness and ownership verification of premium digital assets.
- **Resale Market:** Allows for the resale of products with a 3% fee payable in ABT on the final sale price, promoting liquidity and active trading across communities.



### Smart Contracts
The platform's functionalities are enabled through several smart contracts:
- `ArtBlockAMM.sol` for token exchanges.
- `ArtBlockGovernance.sol` for community governance.
- `ArtBlockNFT.sol` for handling NFTs.
- `ARTBlockVoting.sol` for voting mechanisms.
- `CustomERC20Token.sol` for community-specific tokens.
- `MainEngine.sol` for overall platform integration.


## Contracts

## Smart Contracts Overview

The ArtBlockForge platform employs a series of smart contracts to facilitate various functionalities, from tokenomics and governance to community interaction and marketplace dynamics. Here's a brief overview of each contract and its role within the platform:

### `ArtBlockAMM.sol`
- **Purpose:** Manages the automated market-making (AMM) functionalities for ArtBlock Tokens.
- **Functionality:** This contract handles the buying and selling of ABT tokens through a dynamic pricing model determined by a bonding curve. It ensures liquidity and fair pricing as the supply and demand of the token change over time.

### `ArtBlockGovernance.sol`
- **Purpose:** Facilitates governance mechanisms within each community on the platform.
- **Functionality:** Allows community members to propose, vote on, and implement changes within their community. This includes decisions related to community-specific rules, tokenomics, and other governance aspects. It ensures that community decisions are decentralized and driven by member consensus.

### `ArtBlockNFT.sol`
- **Purpose:** Manages the creation and trade of non-fungible tokens (NFTs) for exclusive products on the platform.
- **Functionality:** This contract allows users to mint NFTs for exclusive items, ensuring their uniqueness and ownership. It also handles the trading of these NFTs within the platform’s marketplace, providing a secure and transparent environment for high-value transactions.

### `ARTBlockVoting.sol`
- **Purpose:** Oversees the voting processes for product listings and other community decisions.
- **Functionality:** Implements a weighted voting system that considers both ABT and community tokens to determine the outcome of votes. This contract ensures that the voting process is fair, reflecting the stakes of community members in platform governance.

### `CustomERC20Token.sol`
- **Purpose:** Allows the creation of custom ERC-20 tokens for individual communities within the platform.
- **Functionality:** Each community can have its own token, which is used for transactions, governance, and rewards within that community. This contract facilitates the issuance and management of these tokens, tailored to the specific needs and rules of each community.

### `MainEngine.sol`
- **Purpose:** Acts as the central engine that integrates all other contracts and functionalities.
- **Functionality:** Coordinates interactions between different contracts, ensuring they work together seamlessly. It manages user interactions, token flows, and data across the platform, serving as the backbone of the ArtBlockForge ecosystem.

These contracts collectively enable the ArtBlockForge platform to operate as a robust, decentralized system where communities can flourish under their governance structures, engage in dynamic economic activities, and enjoy secure, transparent transactions.



## Installation and Deployment

To deploy the smart contracts, follow these steps:

1. **Clone the Repository:**
```bash
git clone https://github.com/your-repo/artblock-platform.git
cd artblock-platform
forge install
```
2. **Build**

```shell
$ forge build
```

3. **Test**

```shell
$ forge test
```

4. **Format**

```shell
$ forge fmt
```

5. **Gas Snapshots**

```shell
$ forge snapshot
```
<!-- 
 Needed to fix this
7. **Deploy**

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```
-->
## Contributing
We welcome contributions to the ArtBlock Platform! Please fork the repository and submit pull requests for any improvements or bug fixes. Ensure your code follows our coding standards and includes appropriate tests.

## License
<!-- This project is licensed under the MIT License. See the LICENSE file for details. -->
