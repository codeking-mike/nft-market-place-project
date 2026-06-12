// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

contract NftMarket is
    IERC721Receiver,
    ReentrancyGuard,
    Ownable,
    Pausable
{
    // =============================================================
    //                           ERRORS
    // =============================================================

    error InvalidPrice();
    error InvalidOwnerAddress();
    error InvalidFee();
    error ListingNotActive();
    error NotSeller();
    error IncorrectPayment();
    error NotTokenOwner();
    error MarketplaceNotApproved();
    error AlreadyListed();
    error NoFeesAvailable();
    error TransferFailed();
    error NotOwner();

    // =============================================================
    //                          CONSTANTS
    // =============================================================

    uint256 public constant MAX_PLATFORM_FEE = 200; // 2%

    // =============================================================
    //                          STORAGE
    // =============================================================

    uint256 public platformFees;
    uint256 public accumulatedFees;
    uint256 public listingIdCounter;

    address public immutable marketPlaceOwner;

    enum NftStatus {
        Active,
        Sold,
        Delisted
    }

    struct NftListing {
        uint256 listingId;
        address seller;
        address nftAddress;
        uint256 tokenId;
        uint256 price;
        NftStatus status;
    }

    mapping(uint256 => NftListing) public listings;

    mapping(address => mapping(uint256 => bool)) public isListed;

    // =============================================================
    //                           EVENTS
    // =============================================================

    event NFTListed(
        uint256 indexed listingId,
        address indexed seller,
        address indexed nftAddress,
        uint256 tokenId,
        uint256 price
    );

    event NFTSold(
        uint256 indexed listingId,
        address indexed buyer,
        address indexed nftAddress,
        uint256 tokenId,
        uint256 price,
        uint256 feeCharged
    );

    event ListingCancelled(
        uint256 indexed listingId,
        address indexed seller,
        address indexed nftAddress,
        uint256 tokenId
    );

    event ListingPriceUpdated(
        uint256 indexed listingId,
        uint256 oldPrice,
        uint256 newPrice
    );

    event PlatformFeeUpdated(
        uint256 oldFee,
        uint256 newFee
    );

    event FeesWithdrawn(
        address indexed owner,
        uint256 amount
    );

    // =============================================================
    //                         CONSTRUCTOR
    // =============================================================

    constructor(
        uint256 _platformFees,
        address _marketPlaceOwner
    ) Ownable(_marketPlaceOwner) {
        if (_marketPlaceOwner == address(0))
            revert InvalidOwnerAddress();

        if (_platformFees > MAX_PLATFORM_FEE)
            revert InvalidFee();

        platformFees = _platformFees;
        marketPlaceOwner = _marketPlaceOwner;
    }

    // =============================================================
    //                       LIST NFT
    // =============================================================

    function listNft(
        address _nftAddress,
        uint256 _tokenId,
        uint256 _price
    ) external whenNotPaused {
        if (_price == 0) revert InvalidPrice();

        if (isListed[_nftAddress][_tokenId])
            revert AlreadyListed();

        IERC721 nftContract = IERC721(_nftAddress);

        if (nftContract.ownerOf(_tokenId) != msg.sender)
            revert NotTokenOwner();

        bool approved =
            nftContract.isApprovedForAll(
                msg.sender,
                address(this)
            ) ||
            nftContract.getApproved(_tokenId) ==
            address(this);

        if (!approved)
            revert MarketplaceNotApproved();

        listingIdCounter++;

        listings[listingIdCounter] = NftListing({
            listingId: listingIdCounter,
            seller: msg.sender,
            nftAddress: _nftAddress,
            tokenId: _tokenId,
            price: _price,
            status: NftStatus.Active
        });

        isListed[_nftAddress][_tokenId] = true;

        nftContract.safeTransferFrom(
            msg.sender,
            address(this),
            _tokenId
        );

        emit NFTListed(
            listingIdCounter,
            msg.sender,
            _nftAddress,
            _tokenId,
            _price
        );
    }

    // =============================================================
    //                       BUY NFT
    // =============================================================

    function buyNft(
        uint256 _listingId
    )
        external
        payable
        nonReentrant
        whenNotPaused
    {
        NftListing storage listing =
            listings[_listingId];

        if (listing.status != NftStatus.Active)
            revert ListingNotActive();

        if (msg.value != listing.price)
            revert IncorrectPayment();

        listing.status = NftStatus.Sold;

        isListed[
            listing.nftAddress
        ][listing.tokenId] = false;

        uint256 feeCharged =
            (listing.price * platformFees) /
            10000;

        uint256 sellerPayout =
            listing.price - feeCharged;

        accumulatedFees += feeCharged;

        // Transfer NFT first
        IERC721(listing.nftAddress)
            .safeTransferFrom(
                address(this),
                msg.sender,
                listing.tokenId
            );

        // Pay seller second
        (bool successSeller, ) =
            payable(listing.seller).call{
                value: sellerPayout
            }("");

        if (!successSeller)
            revert TransferFailed();

        emit NFTSold(
            _listingId,
            msg.sender,
            listing.nftAddress,
            listing.tokenId,
            listing.price,
            feeCharged
        );
    }

    // =============================================================
    //                    CANCEL LISTING
    // =============================================================

    function cancelListing(
        uint256 _listingId
    ) external whenNotPaused {
        NftListing storage listing =
            listings[_listingId];

        if (listing.status != NftStatus.Active)
            revert ListingNotActive();

        if (listing.seller != msg.sender)
            revert NotSeller();

        listing.status = NftStatus.Delisted;

        isListed[
            listing.nftAddress
        ][listing.tokenId] = false;

        IERC721(listing.nftAddress)
            .safeTransferFrom(
                address(this),
                listing.seller,
                listing.tokenId
            );

        emit ListingCancelled(
            _listingId,
            msg.sender,
            listing.nftAddress,
            listing.tokenId
        );
    }

    // =============================================================
    //                  UPDATE LISTING PRICE
    // =============================================================

    function updateListingPrice(
        uint256 _listingId,
        uint256 _newPrice
    ) external whenNotPaused {
        if (_newPrice == 0)
            revert InvalidPrice();

        NftListing storage listing =
            listings[_listingId];

        if (listing.status != NftStatus.Active)
            revert ListingNotActive();

        if (listing.seller != msg.sender)
            revert NotSeller();

        uint256 oldPrice = listing.price;

        listing.price = _newPrice;

        emit ListingPriceUpdated(
            _listingId,
            oldPrice,
            _newPrice
        );
    }

    // =============================================================
    //                 UPDATE PLATFORM FEES
    // =============================================================

    function updatePlatformFees(
        uint256 _newPlatformFees
    ) external onlyOwner {
        if (_newPlatformFees > MAX_PLATFORM_FEE)
            revert InvalidFee();

        uint256 oldFee = platformFees;

        platformFees = _newPlatformFees;

        emit PlatformFeeUpdated(
            oldFee,
            _newPlatformFees
        );
    }

    // =============================================================
    //                  WITHDRAW FEES
    // =============================================================

    function withdrawPlatformFees()
        external
        onlyOwner
        nonReentrant
    {
        uint256 fees = accumulatedFees;

        if (fees == 0)
            revert NoFeesAvailable();

        accumulatedFees = 0;

        (bool success, ) =
            payable(marketPlaceOwner).call{
                value: fees
            }("");

        if (!success)
            revert TransferFailed();

        emit FeesWithdrawn(
            marketPlaceOwner,
            fees
        );
    }

    // =============================================================
    //                       PAUSABLE
    // =============================================================

    function pause()
        external
        onlyOwner
    {
        _pause();
    }

    function unpause()
        external
        onlyOwner
    {
        _unpause();
    }

    // =============================================================
    //                  ERC721 RECEIVER
    // =============================================================

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    )
        external
        pure
        override
        returns (bytes4)
    {
        return
            IERC721Receiver
                .onERC721Received
                .selector;
    }

    // =============================================================
    //                     VIEW HELPERS
    // =============================================================

    function getListing(uint256 _listingId) external view returns (NftListing memory)
    {
        return listings[_listingId];
    }


function getListingCount() external view returns (uint256)
{
    return listingIdCounter;
}

function getActiveListing(uint256 listingId) external view returns (NftListing memory)
{
    return listings[listingId];
}




}