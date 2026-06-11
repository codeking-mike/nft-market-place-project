// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {Test} from "forge-std/Test.sol";
import {NftMarket} from "../src/NftMarket.sol";
import {MockNft} from "./MockNft.sol";

contract NftMarketFuzz is Test {
    NftMarket public market;
    MockNft public nft;

    address public seller = address(0x1);
    address public buyer = address(0x2);
    address public nonOwner = address(0x3);

    uint256 public constant TOKEN_ID = 1;
    uint256 public constant PRICE = 1 ether;

    function setUp() public {
        market = new NftMarket(200, address(this)); // 2.5% platform fee
        nft = new MockNft();
        nft.mint(seller, TOKEN_ID);
    }

    function testFuzz_ListAndBuy(uint96 price) public{
    vm.assume(
        price > 0
    );

    vm.startPrank(
        seller
    );

    nft.setApprovalForAll(
        address(market),
        true
    );

    market.listNft(
        address(nft),
        TOKEN_ID,
        price
    );

    vm.stopPrank();
    vm.deal(
        buyer,
        price
    );

    vm.prank(buyer);

    market.buyNft{
        value: price
    }(1);

    assertEq(
        nft.ownerOf(
            TOKEN_ID
        ),
        buyer
    );
  }

}
        