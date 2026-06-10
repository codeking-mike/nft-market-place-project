# NFT Marketplace Project

A Foundry-based NFT marketplace smart contract that allows sellers to list ERC-721 tokens for sale, buyers to purchase listed NFTs with ETH, and the marketplace owner to collect platform fees.

## Project Summary

This repository contains a simple, secure NFT marketplace built with Solidity and tested using Foundry.

Key capabilities:
- List ERC-721 NFTs for sale using `NftMarket.listNft`
- Store listings in escrow inside the marketplace contract
- Buy active listings with exact ETH payment
- Calculate and collect a platform fee on each sale
- Cancel active listings and return NFTs to sellers
- Update platform fees and withdraw accumulated fees as marketplace owner

The marketplace contract is implemented in `src/NftMarket.sol`, and the deployment script is in `script/DeployNftMarket.s.sol`.

## Core Contract Behavior

`NftMarket.sol` provides:
- `listNft(address nftAddress, uint256 tokenId, uint256 price)`
  - transfers the NFT into escrow after verifying ownership and approval
  - records a new active listing
- `buyNft(uint256 listingId)`
  - checks that the listing is active and the buyer sends the exact price
  - transfers funds to the seller after deducting platform fees
  - transfers the NFT from escrow to the buyer
- `cancelListing(uint256 listingId)`
  - allows the seller to cancel an active listing and recover the NFT
- `updatePlatformFees(uint256 newPlatformFees)`
  - only owner can change the fee rate
- `withdrawPlatformFees()`
  - only owner can withdraw accumulated ETH from completed sales

## Testing

The contract is covered by Foundry tests in `test/NftMarket.t.sol`.

Tests verify:
- successful listing and escrow transfer
- approval and ownership requirements for listings
- purchase flow and fee distribution
- cancellation behavior and active listing validation
- owner-only access for fee updates and withdrawals

## Getting Started

### Prerequisites

- Foundry installed
- `forge`, `anvil`, and `cast` available in your PATH

### Build

```sh
forge build
```

### Run tests

```sh
forge test
```

### Format code

```sh
forge fmt
```

### Run local node

```sh
anvil
```

## Deployment

Deploy the marketplace contract using the script:

```sh
forge script script/DeployNftMarket.s.sol:DeployNftMarket --rpc-url <RPC_URL> --private-key <PRIVATE_KEY>
```

The deployment script initializes the contract with a default platform fee of 2.5% (250 basis points) and sets the deployer as the marketplace owner.

## Repository Structure

- `src/NftMarket.sol` — marketplace contract implementation
- `test/NftMarket.t.sol` — Foundry tests for marketplace behavior
- `script/DeployNftMarket.s.sol` — deployment script for `forge script`
- `test/MockNft.sol` — ERC-721 mock used for testing

## Notes

- The marketplace uses OpenZeppelin interfaces and `ReentrancyGuard` for secure transfers.
- Fees are stored in basis points, where `10000` represents `100%`.
