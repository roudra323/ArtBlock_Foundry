# ArtBlock Platform - Smart Contracts

Welcome to the ArtBlock Platform! This README provides an overview of the smart contracts used in the ArtBlock Platform, a decentralized creator-based community focusing on various forms of art. These communities operate as Decentralized Autonomous Organizations (DAOs) with no centralized power dictating their operations. Below, you'll find detailed information about each smart contract, their purpose, and how they interact within the ArtBlock ecosystem.

## Overview

The ArtBlock Platform comprises several smart contracts to manage various aspects of the platform, including community creation, token management, content publication, voting, NFT minting, and marketplace integration. The primary contracts included in this repository are:

1. `ArtBlockAMM.sol`
2. `ArtBlockGovernance.sol`
3. `ArtBlockNFT.sol`
4. `ARTBlockVoting.sol`
5. `CustomERC20Token.sol`
6. `MainEngine.sol`

## Contracts

### 1. `ArtBlockAMM.sol`

This contract manages the Automated Market Maker (AMM) for the ArtBlock ecosystem. It handles the exchange of ABX tokens and community native tokens. Key functionalities include:
- Token swaps between ABX and community native tokens.
- Liquidity management for the tokens.

### 2. `ArtBlockGovernance.sol`

The governance contract is central to the DAO operations within the ArtBlock Platform. It facilitates:
- Creation of new communities by spending a fixed amount of ABX tokens.
- Generation of unique community native tokens for each new community.
- Management of community reserves.

### 3. `ArtBlockNFT.sol`

This contract handles the minting and management of NFTs within the platform. It supports:
- Minting of NFTs for approved art products.
- Dutch auction mechanism for exclusive items.
- Transfer and royalty management for NFTs.

### 4. `ARTBlockVoting.sol`

The voting contract enables community members to vote on the approval of art products. It includes:
- Staking mechanism for product publication.
- Voting system with weighted votes based on community native tokens held.
- Transfer of staked tokens to the community reserve if the product is not approved.

### 5. `CustomERC20Token.sol`

This contract implements the ERC20 standard for both ABX tokens and community native tokens. Key features include:
- Standard ERC20 functionalities (transfer, approve, transferFrom).
- Additional functionalities to support the platform's needs.

### 6. `MainEngine.sol`

The MainEngine contract integrates all the functionalities and coordinates the interactions between different contracts. It includes:
- User interface for purchasing ABX tokens.
- Mechanism for creating new communities.
- Coordination of NFT minting and marketplace activities.

## Platform Scenario

The ArtBlock Platform aims to create a creator-based community for different types of art. Key features of the platform include:

- **Community Creation:** Users can create new communities by spending ABX tokens. Each community has its own native token.
- **Content Publication:** Creators can publish art products categorized as exclusive or general. Exclusive items undergo a Dutch auction, while general items are listed on the marketplace.
- **Voting System:** Community members vote on the approval of products. The voting weight is determined by the amount of community native tokens held.
- **NFT Minting:** Approved art products are minted as NFTs. Exclusive items use a Dutch auction mechanism for pricing.
- **Marketplace Integration:** A marketplace where users can buy and resell NFTs using community native tokens. Original creators receive royalties on resales.

## Installation and Deployment

To deploy the smart contracts, follow these steps:

1. **Clone the Repository:**
   ```bash
   git clone https://github.com/your-repo/artblock-platform.git
   cd artblock-platform
   forge install

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

6. **Anvil**

```shell
$ anvil
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
This project is licensed under the MIT License. See the LICENSE file for details.
