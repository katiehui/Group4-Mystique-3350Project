// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol"; // Import the IERC721 interface from OpenZeppelin
import "@openzeppelin/contracts/access/Ownable.sol"; // Import the Ownable contract from OpenZeppelin
import "./Random generation of NFT v11.sol"; // Import the BlindBox contract

contract Auction is Ownable { // Define the Auction contract and inherit from Ownable
    struct AuctionData { // Define the AuctionData struct
        address seller; // The address of the seller
        uint256 tokenId; // The ID of the BlindBox NFT being auctioned
        uint256 startingPrice; // The starting price of the auction
        uint256 highestBid; // The highest bid amount
        address highestBidder; // The address of the highest bidder
        bool exists; // Whether the auction exists or not
        bool ended; // Whether the auction has ended or not
        uint256 startTime; // The start time of the auction in seconds since the Unix epoch.
    }

    mapping(uint256 => AuctionData) public auctions; // Mapping of BlindBox NFT IDs to auction data
    IERC721 public blindBoxContract; // The BlindBox contract instance
    BlindBox private blindBox; // The BlindBox contract instance
    uint256 constant AUCTION_DURATION = 60; // The fixed duration of all auctions, in seconds

    event AuctionCreated(uint256 indexed tokenId, uint256 startingPrice); // Event emitted when a new auction is created
    event BidPlaced(uint256 indexed tokenId, address bidder, uint256 amount); // Event emitted when a bid is placed on an auction
    event AuctionEnded(uint256 indexed tokenId, address winner, uint256 amount); // Event emitted when an auction ends
    event ElapsedTime(uint256 indexed tokenId, uint256 elapsedTime); // Event emitted when an auction ends to show elapsed time

    constructor(address _blindBoxContract) { // Constructor that takes the address of the BlindBox contract
        blindBoxContract = IERC721(_blindBoxContract); // Initialize the BlindBox contract instance
        blindBox = BlindBox(_blindBoxContract); // Initialize the BlindBox contract instance
    }

    /**
     * @dev Create a new auction for a BlindBox NFT.
     * @param tokenId The ID of the BlindBox NFT to auction.
     * @param startingPrice The starting price of the auction in Ether.
     */
    function createAuction(uint256 tokenId, uint256 startingPrice) external {
        require(blindBoxContract.ownerOf(tokenId) == msg.sender, "Auction: Caller must be owner of token"); // Check that the caller is the owner of the BlindBox NFT
        require(!auctions[tokenId].exists, "Auction: Auction already exists for token or ended"); // Check that an auction doesn't already exist for the BlindBox NFT

        AuctionData storage auction = auctions[tokenId]; // Get the auction data for the BlindBox NFT
        auction.seller = msg.sender; // Set the seller to the caller
        auction.tokenId = tokenId; // Set the BlindBox NFT ID
        auction.startingPrice = startingPrice; // Set the starting price
        auction.startTime = block.timestamp; // Set the auction start time to the current block timestamp
        auction.exists = true; // Set the auction to exist

        emit AuctionCreated(tokenId, startingPrice); // Emit the AuctionCreated event
    }

    /**
     * @dev Place a bid on an auction for a BlindBox NFT.
     * @param tokenId The ID of the BlindBox NFT to bid on.
     */
    function placeBid(uint256 tokenId) external payable {
        AuctionData storage auction = auctions[tokenId]; // Get the auction data for the BlindBox NFT
        require(msg.sender != auctions[tokenId].seller, "Auction: Seller please do not bid on your own items"); //Prevent self bidding
        require(auction.exists, "Auction: No auction exists for token"); // Check that an auction exists for the BlindBox NFT
        require(block.timestamp < auction.startTime + AUCTION_DURATION, "Auction: Auction times up, pending for owner to end auction."); // Check that auction times out automatically, in case seller did not end the auction
        require(!auction.ended, "Auction: Auction has ended"); // Check that the auction has not ended
        require(msg.value >= auction.startingPrice * 1 ether, "Auction: Bid must be greater than or equal to starting price"); // Check that the bid amount is greater than or equal to the starting price
        require(msg.value > auction.highestBid * 1 ether, "Auction: Bid must be greater than highest bid"); // Check that the bid amount is greater than the current highest bid

        if (auction.highestBid > 0) { // If there was a previous highest bid
            payable(auction.highestBidder).transfer(auction.highestBid); // Refund the previous highest bidder
        }

        auction.highestBid = msg.value / 1 ether; // Set the highest bid amount to the amount sent with the transaction, divided by 1 ether
        auction.highestBidder = msg.sender; // Set the highest bidder to the caller

        emit BidPlaced(tokenId, msg.sender, msg.value); // Emit the BidPlaced event
    }

    /**
    * @dev End an auction for a BlindBox NFT and transfer the NFT to the highest bidder.
    * @param tokenId The ID of the BlindBox NFT to end the auction for.
    */
    function endAuction(uint256 tokenId) external {
        AuctionData storage auction = auctions[tokenId]; // Get the auction data for the BlindBox NFT
        require(auction.exists, "Auction: No auction exists for token"); // Check that an auction exists for the BlindBox NFT
        require(!auction.ended, "Auction: Auction has already ended"); // Check that the auction has not already ended
        require(block.timestamp >= auction.startTime + AUCTION_DURATION, "Auction: Auction has not ended yet"); // Check that the auction has ended

        auction.ended = true; // Set the auction to have ended

        if(auction.highestBid > 0) { // If there is a bid by any user
            blindBox.safeTransferFrom(auction.seller, auction.highestBidder, auction.tokenId); // Transfer the BlindBox NFT to the highest bidder
            payable(auction.seller).transfer(auction.highestBid * 1 ether); // Transfer the highest bid amount to the seller

            emit AuctionEnded(tokenId, auction.highestBidder, auction.highestBid * 1 ether); // Emit the AuctionEnded event
        }
            else { // If there were no bids
                    emit AuctionEnded(tokenId, address(0), 0); // Emit the AuctionEnded event with no winner and 0 amount
                }
    }

    function checkNftOwner(uint256 tokenId) external view returns (address) {
        return blindBoxContract.ownerOf(tokenId); // Return the address of current owner of the BlindBox NFT
    }

}
