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
    uint256 public constant PLATFORM_FEE = 100;

    function setUp() public {
        nft = new MockNft();
        market = new NftMarket(PLATFORM_FEE, marketOwner);

        vm.prank(seller);
        nft.mint(seller, TOKEN_ID);
    }

    function _listDefaultNFT() internal {
        vm.startPrank(seller);

        nft.setApprovalForAll(address(market), true);

        market.listNft(
            address(nft),
            TOKEN_ID,
            PRICE
        );

        vm.stopPrank();
    }

    function _buyDefaultNFT(
        address buyer
    ) internal {
        vm.deal(buyer, PRICE);

        vm.prank(buyer);

        market.buyNft{value: PRICE}(1);
    }

    function testCannotListSameNFTTwice() public
        {
            _listDefaultNFT();

            vm.expectRevert(
                NftMarket.AlreadyListed.selector
            );

            vm.prank(seller);

            market.listNft(
                address(nft),
                TOKEN_ID,
                PRICE
            );
        }

        function testListNFT_SetsIsListedFlag() public
    {
        _listDefaultNFT();

        assertTrue(
            market.isListed(
                address(nft),
                TOKEN_ID
            )
        );
    }

    function testListNFT_TransfersTokenAndStoresListing() public {
        vm.prank(seller);
        nft.setApprovalForAll(address(market), true);

        vm.prank(seller);
        market.listNft(address(nft), TOKEN_ID, PRICE);

        assertEq(market.listingIdCounter(), 1);

        (
            uint256 listingId,
            address listedSeller,
            address listedNftAddress,
            uint256 listedTokenId,
            uint256 listedPrice,
            NftMarket.NftStatus status
        ) = market.listings(1);

        assertEq(listingId, 1);
        assertEq(listedSeller, seller);
        assertEq(listedNftAddress, address(nft));
        assertEq(listedTokenId, TOKEN_ID);
        assertEq(listedPrice, PRICE);
        assertEq(uint8(status), uint8(NftMarket.NftStatus.Active));
        assertEq(nft.ownerOf(TOKEN_ID), address(market));
    }

    function testListNFT_RevertsWhenMarketplaceNotApproved() public {
        uint256 unapprovedTokenId = 2;

        vm.prank(seller);
        nft.mint(seller, unapprovedTokenId);

        vm.prank(seller);
        vm.expectRevert(NftMarket.MarketplaceNotApproved.selector);
        market.listNft(address(nft), unapprovedTokenId, PRICE);
    }

    function testListNFT_RevertsWhenPriceIsZero() public {
        vm.prank(seller);
        nft.setApprovalForAll(address(market), true);

        vm.prank(seller);
       vm.expectRevert(NftMarket.InvalidPrice.selector);
        market.listNft(address(nft), TOKEN_ID, 0);
    }

    function testListNFT_RevertsWhenCallerIsNotOwner() public {
        address nonOwner = makeAddr("nonOwner");

        vm.prank(seller);
        nft.setApprovalForAll(address(market), true);

        vm.prank(nonOwner);
        vm.expectRevert(NftMarket.NotTokenOwner.selector);
        market.listNft(address(nft), TOKEN_ID, PRICE);
    }

    function testBuyNFT_SuccessfulPurchase() public {
        // Setup: List NFT first
        vm.prank(seller);
        nft.setApprovalForAll(address(market), true);

        vm.prank(seller);
        market.listNft(address(nft), TOKEN_ID, PRICE);

        // Create buyer
        address buyer = makeAddr("buyer");
        vm.deal(buyer, PRICE);

        // Execute purchase
        vm.prank(buyer);
        market.buyNft{value: PRICE}(1);

        // Verify NFT transferred to buyer
        assertEq(nft.ownerOf(TOKEN_ID), buyer);

        // Verify listing marked as sold
        (, , , , , NftMarket.NftStatus status) = market.listings(1);
        assertEq(uint8(status), uint8(NftMarket.NftStatus.Sold));

        // Verify seller received payment (after fee)
        uint256 expectedFee = (PRICE * PLATFORM_FEE) / 10000;
        uint256 expectedSellerPayout = PRICE - expectedFee;
        assertEq(seller.balance, expectedSellerPayout);
    }

    function testBuyNFT_RevertsWhenListingNotActive() public {
        vm.prank(seller);
        nft.setApprovalForAll(address(market), true);

        vm.prank(seller);
        market.listNft(address(nft), TOKEN_ID, PRICE);

        // Cancel the listing first
        vm.prank(seller);
        market.cancelListing(1);

        // Try to buy delisted NFT
        address buyer = makeAddr("buyer");
        vm.deal(buyer, PRICE);

        vm.prank(buyer);
        vm.expectRevert(NftMarket.ListingNotActive.selector);
        market.buyNft(1);
    }

    function testBuyNFT_RevertsWithIncorrectETHAmount() public {
        vm.prank(seller);
        nft.setApprovalForAll(address(market), true);

        vm.prank(seller);
        market.listNft(address(nft), TOKEN_ID, PRICE);

        address buyer = makeAddr("buyer");
        vm.deal(buyer, PRICE / 2); // Not enough

        vm.prank(buyer);
        vm.expectRevert(NftMarket.IncorrectPayment.selector);
        market.buyNft{value: PRICE / 2}(1);
    }

    function testCancelListing_SuccessfullyCancels() public {
        vm.prank(seller);
        nft.setApprovalForAll(address(market), true);

        vm.prank(seller);
        market.listNft(address(nft), TOKEN_ID, PRICE);

        vm.prank(seller);
        market.cancelListing(1);

        // Verify NFT returned to seller
        assertEq(nft.ownerOf(TOKEN_ID), seller);

        // Verify listing marked as delisted
        (, , , , , NftMarket.NftStatus status) = market.listings(1);
        assertEq(uint8(status), uint8(NftMarket.NftStatus.Delisted));
    }

    function testCancelListing_ClearsIsListed()
    public
        {
            _listDefaultNFT();

            vm.prank(seller);

            market.cancelListing(1);

            assertFalse(
                market.isListed(
                    address(nft),
                    TOKEN_ID
                )
            );
        }
     function testBuyNFT_ClearsIsListed() public{
        _listDefaultNFT();

        address buyer =
            makeAddr("buyer");

        _buyDefaultNFT(buyer);

        assertFalse(
            market.isListed(
                address(nft),
                TOKEN_ID
            )
        );
    }

    function testBuyNFT_AccumulatesFees() public{
        _listDefaultNFT();

        address buyer =
            makeAddr("buyer");

        _buyDefaultNFT(buyer);

        uint256 expectedFee =
            (PRICE * PLATFORM_FEE)
                / 10000;

        assertEq(
            market.accumulatedFees(),
            expectedFee
        );
    }

    function testWithdrawFees_ResetsAccumulator() public{
        _listDefaultNFT();

        address buyer =
            makeAddr("buyer");

        _buyDefaultNFT(buyer);

        vm.prank(marketOwner);

        market.withdrawPlatformFees();

        assertEq(
            market.accumulatedFees(),
            0
        );
    }

    function testCancelListing_RevertsIfNotSeller() public {
        vm.prank(seller);
        nft.setApprovalForAll(address(market), true);

        vm.prank(seller);
        market.listNft(address(nft), TOKEN_ID, PRICE);

        address nonSeller = makeAddr("nonSeller");
        vm.prank(nonSeller);
        vm.expectRevert(NftMarket.NotSeller.selector);
        market.cancelListing(1);
    }

    function testUpdatePlatformFees_OnlyOwner() public {
        uint256 newFee = 25;
        
        vm.prank(marketOwner);
        market.updatePlatformFees(newFee);

        assertEq(market.platformFees(), newFee);
    }

/*
    function testUpdatePlatformFees_RevertsIfNotOwner() public {
        address nonOwner = makeAddr("nonOwner");

        vm.prank(nonOwner);
        vm.expectRevert(NftMarket.NotOwner.selector);
        market.updatePlatformFees(25);
    } */

    function testWithdrawPlatformFees_OnlyOwner() public {
        // Setup: Perform a transaction to generate fees
        vm.prank(seller);
        nft.setApprovalForAll(address(market), true);

        vm.prank(seller);
        market.listNft(address(nft), TOKEN_ID, PRICE);

        address buyer = makeAddr("buyer");
        vm.deal(buyer, PRICE);

        vm.prank(buyer);
        market.buyNft{value: PRICE}(1);

        // Withdraw fees as owner
        uint256 contractBalance = address(market).balance;
        vm.prank(marketOwner);
        market.withdrawPlatformFees();

        // Verify balance transferred to owner
        assertEq(marketOwner.balance, contractBalance);
    }

    function testWithdrawPlatformFees_RevertsWithNoFees() public {
        vm.prank(marketOwner);
        vm.expectRevert(NftMarket.NoFeesAvailable.selector);
        market.withdrawPlatformFees();
    }

    function testUpdateListingPrice() public{
            _listDefaultNFT();

            uint256 newPrice =
                2 ether;

            vm.prank(seller);

            market.updateListingPrice(
                1,
                newPrice
            );

            (
                ,
                ,
                ,
                ,
                uint256 price,

            ) = market.listings(1);

            assertEq(
                price,
                newPrice
            );
        }
        //non seller cannot update price
    function testUpdateListingPrice_RevertsForNonSeller() public{
        _listDefaultNFT();

        address attacker =
            makeAddr("attacker");

        vm.prank(attacker);

        vm.expectRevert(
            NftMarket.NotSeller.selector
        );

        market.updateListingPrice(
            1,
            2 ether
        );
    }

    //pause tests

    function testPauseStopsListing() public{
        vm.prank(marketOwner);

        market.pause();

        vm.startPrank(seller);

        nft.setApprovalForAll(
            address(market),
            true
        );

        vm.expectRevert();

        market.listNft(
            address(nft),
            TOKEN_ID,
            PRICE
        );

        vm.stopPrank();
    }

    function testPauseStopsBuying() public{
        _listDefaultNFT();

        vm.prank(marketOwner);

        market.pause();

        address buyer =
            makeAddr("buyer");

        vm.deal(
            buyer,
            PRICE
        );

        vm.prank(buyer);

        vm.expectRevert();

        market.buyNft{
            value: PRICE
        }(1);
    }

    function testConstructorRejectsFeeAboveMax() public{
        vm.expectRevert(
            NftMarket.InvalidFee.selector
        );

        new NftMarket(
            1001,
            marketOwner
        );
    }

    function testUpdateFeeRejectsAboveMax() public{
        vm.prank(marketOwner);

        vm.expectRevert(
            NftMarket.InvalidFee.selector
        );

        market.updatePlatformFees(
            1001
        );
    }

    function testCannotBuySoldNFT() public{
        _listDefaultNFT();

        address buyer1 =
            makeAddr("buyer1");

        _buyDefaultNFT(
            buyer1
        );

        address buyer2 =
            makeAddr("buyer2");

        vm.deal(
            buyer2,
            PRICE
        );

        vm.prank(buyer2);

        vm.expectRevert(
            NftMarket
                .ListingNotActive
                .selector
        );

        market.buyNft{
            value: PRICE
        }(1);
    }








}
