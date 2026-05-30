//SPDX-License-Identifier: MIT

pragma solidity ^0.8.33;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC20}  from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";


contract NftMarket is IERC721Receiver {

     uint256 public platformFees; //platform fees charged for each purchase(either in percentage or fixed amount)
     address public marketPlaceOwner; // The address that receieves the platformFess 
     uint256 public listingIdCounter; // a counter that holds every unique listing in the smart contract 

     enum nftStatus {Active, Sold, Delisted}

     struct nftListing {
        uint256 listingId;
        address seller;
        address nftAddress;
        uint256 tokenId;
        uint256 price; // price in wei
        nftStatus status;
     }

     mapping (uint256 => nftListing) public listings;

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
    function ListNFT(address _nftAddress, uint256 _tokenId, uint256 _price) public {
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

    listings[currentListingId] = nftListing({
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


    
    //cancel listing function
    function cancelListing(uint256 _listingId) public {
        nftListing storage listing = listings[_listingId];
        require(listing.status == nftStatus.Active, "Listing is not active");
        require(listing.seller == msg.sender, "Only the seller can cancel this listing");
        listing.status = nftStatus.Delisted;

    emit ListingCancelled(_listingId, msg.sender);

        // Transfer the NFT back to the seller
        IERC721(listing.nftAddress).safeTransferFrom(address(this), listing.seller, listing.tokenId);
    }


}

       
