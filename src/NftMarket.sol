//SPDX-License-Identifier: MIT

pragma solidity ^0.8.33;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract NftMarket is IERC721Receiver {

     uint256 public immutable platformFees; //platform fees charged for each purchase(either in percentage or fixed amount)
     address public constant MARKETPLACE_OWNER; // The address that receieves the platformFess 
     uint256 public listingIdCounter; // a counter that holds every unique listing in the smart contract 

     enum nftStatus {Active, Sold, Delisted}

     struct NftListing {
        uint256 listingId;
        address seller;
        address nftAddress;
        uint256 tokenId;
        uint256 price; // price in wei
        nftStatus status;
     }

     mapping (uint256 => NftListing) public listings;

     //events for front end integration

        event NFTListed(uint256 indexed listingId, address indexed seller, address indexed nftAddress, uint256 tokenId, uint256 price);
        event NFTSold(uint256 indexed listingId, address indexed buyer, address indexed nftAddress, uint256 tokenId, uint256 price, uint256 feeCharged);
        event ListingCancelled(uint256 indexed listingId, address indexed seller);
        event PlatformFeeUpdated(uint256 oldFee, uint256 newFee);


    constructor(uint256 _platformFees, address _marketPlaceOwner) {
        platformFees = _platformFees;
        marketPlaceOwner = _marketPlaceOwner;
    }

 //list NFT function
    function listNft(address _nftAddress, uint256 _tokenId, uint256 _price) public {
         require(_price > 0, "Price must be greater than zero");
        
         // Ensure the sender is the actual owner of the NFT before transferring
    IERC721 nftContract = IERC721(_nftAddress);
    require(nftContract.ownerOf(_tokenId) == msg.sender, "Marketplace: You do not own this token");
    
    // Ensure the marketplace is approved to transfer this token
    require(
        nftContract.isApprovedForAll(msg.sender, address(this)) || 
        nftContract.getApproved(_tokenId) == address(this),
        "Marketplace: Contract not approved to transfer token"
    );

    // 2. State Updates
    listingIdCounter++;
    uint256 currentListingId = listingIdCounter;

    listings[currentListingId] = NftListing({
        listingId: currentListingId,
        seller: msg.sender,
        nftAddress: _nftAddress,
        tokenId: _tokenId,
        price: _price,
        status: nftStatus.Active
    });

    // Transfer the NFT from the seller directly into this contract
    nftContract.safeTransferFrom(msg.sender, address(this), _tokenId);

    // 4. Event Emission for Indexers/Frontend
    emit NFTListed(currentListingId, msg.sender, _nftAddress, _tokenId, _price);

    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }


    //BuyNFT function

function buyNft(uint256 _listingId) external payable nonReentrant {
    // 1. Checks
    Listing storage listing = listings[_listingId];
    
    require(listing.status == ListingStatus.Active, "Marketplace: Listing is not active");
    require(msg.value == listing.price, "Marketplace: Incorrect ETH amount sent");

    // 2. Effects
    listing.status = ListingStatus.Sold;

    // 3. Interactions
    // Calculate platform fee cut (e.g., platformFeeBps = 250 means 2.5%)
    uint256 feeCharged = (listing.price * platformFee) / 10000;
    uint256 sellerPayout = listing.price - feeCharged;

    // Transfer payout to the seller
    (bool successSeller, ) = payable(listing.seller).call{value: sellerPayout}("");
    require(successSeller, "Marketplace: Seller payment failed");

    // Transfer the NFT from escrow to the buyer
    IERC721(listing.nftAddress).safeTransferFrom(address(this), msg.sender, listing.tokenId);

    // 4. Emit Event
    emit NFTSold(_listingId, msg.sender, listing.nftAddress, listing.tokenId, listing.price, feeCharged);
}


    
    //cancel listing function
    function cancelListing(uint256 _listingId) public {
        NftListing storage listing = listings[_listingId];
        require(listing.status == nftStatus.Active, "Listing is not active");
        require(listing.seller == msg.sender, "Only the seller can cancel this listing");
        listing.status = nftStatus.Delisted;

    emit ListingCancelled(_listingId, msg.sender);

        // Transfer the NFT back to the seller
        IERC721(listing.nftAddress).safeTransferFrom(address(this), listing.seller, listing.tokenId);
    }




}

       
