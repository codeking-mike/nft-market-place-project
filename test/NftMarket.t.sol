// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Test} from "forge-std/Test.sol";
import {NftMarket} from "../src/NftMarket.sol";
import {MockNft} from "./MockNft.sol";

contract NftMarketTest is Test {
    MockNft public nft;
    NftMarket public market;

    address public seller = makeAddr("seller");
    address public marketOwner = makeAddr("marketOwner");

    uint256 public constant TOKEN_ID = 1;
    uint256 public constant PRICE = 1 ether;
    uint256 public constant PLATFORM_FEE = 10;

    function setUp() public {
        nft = new MockNft();
        market = new NftMarket(PLATFORM_FEE, marketOwner);

        vm.prank(seller);
        nft.mint(seller, TOKEN_ID);
    }

    function testListNFT_TransfersTokenAndStoresListing() public {
        vm.prank(seller);
        nft.setApprovalForAll(address(market), true);

        vm.prank(seller);
        market.ListNFT(address(nft), TOKEN_ID, PRICE);

        assertEq(market.listingIdCounter(), 1);

        (
            uint256 listingId,
            address listedSeller,
            address listedNftAddress,
            uint256 listedTokenId,
            uint256 listedPrice,
            NftMarket.nftStatus status
        ) = market.listings(1);

        assertEq(listingId, 1);
        assertEq(listedSeller, seller);
        assertEq(listedNftAddress, address(nft));
        assertEq(listedTokenId, TOKEN_ID);
        assertEq(listedPrice, PRICE);
        assertEq(uint8(status), uint8(NftMarket.nftStatus.Active));
        assertEq(nft.ownerOf(TOKEN_ID), address(market));
    }

    function testListNFT_RevertsWhenMarketplaceNotApproved() public {
        uint256 unapprovedTokenId = 2;

        vm.prank(seller);
        nft.mint(seller, unapprovedTokenId);

        vm.prank(seller);
        vm.expectRevert("Marketplace: Contract not approved to transfer token");
        market.ListNFT(address(nft), unapprovedTokenId, PRICE);
    }

    function testListNFT_RevertsWhenPriceIsZero() public {
        vm.prank(seller);
        nft.setApprovalForAll(address(market), true);

        vm.prank(seller);
        vm.expectRevert("Price must be greater than zero");
        market.ListNFT(address(nft), TOKEN_ID, 0);
    }

    function testListNFT_RevertsWhenCallerIsNotOwner() public {
        address nonOwner = makeAddr("nonOwner");

        vm.prank(seller);
        nft.setApprovalForAll(address(market), true);

        vm.prank(nonOwner);
        vm.expectRevert("Marketplace: You do not own this token");
        market.ListNFT(address(nft), TOKEN_ID, PRICE);
    }
}
