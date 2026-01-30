// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "fhevm/lib/TFHE.sol";

contract BlindAuction { // ============ STATE VARIABLES ============

// The person who created this auction (has special powers)
address public auctioneer;
// ^ "public" automatically creates a getter function so anyone can see who runs this

// Stores each bidder's encrypted bid amount
mapping(address => euint64) private bids;

// A list of everyone who placed a bid
// We need this because mappings can't be iterated (looped through)
address[] public bidders;
// ^ "address[]" = an array (list) of addresses

// The current highest bid (encrypted - we don't know the actual value!)
euint64 private highestBid;

// The current leader's address (encrypted!)
// "eaddress" = an encrypted wallet address
eaddress private highestBidder;

// Has the auction ended?
bool public auctionEnded;
// ^ Simple true/false flag

// The winner's address (only set after auction ends and is decrypted)
address public winner;

// ============ EVENTS ============

event BidPlaced(address bidder);
event AuctionEnded(address winner);
// ^ We announce the winner's address, but NOT the winning amount

// ============ CONSTRUCTOR ============

// This runs ONCE when the contract is first deployed
constructor() {
    auctioneer = msg.sender;
    // ^ Whoever deploys the contract becomes the auctioneer
    
    // Initialize highest bid to zero (encrypted zero!)
    highestBid = TFHE.asEuint64(0);
    // ^ Even "zero" is encrypted - nobody can tell it's zero by looking at it
    
    // Initialize highest bidder to the zero address (encrypted)
    highestBidder = TFHE.asEaddress(address(0));
    // ^ address(0) = 0x0000...0000 (the "nobody" address)
    
    // Grant the contract permission to work with these encrypted values
    TFHE.allow(highestBid, address(this));
    TFHE.allow(highestBidder, address(this));
}

// ============ MODIFIERS ============

// A reusable check: "only the auctioneer can do this"
modifier onlyAuctioneer() {
    require(msg.sender == auctioneer, "Only auctioneer can call this");
    // ^ If this fails, the transaction reverts (cancels) with that error message
    _;
    // ^ This underscore means "now run the actual function"
}

// A reusable check: "auction must still be running"
modifier auctionOngoing() {
    require(!auctionEnded, "Auction has ended");
    // ^ "!" means "not", so this checks that auctionEnded is false
    _;
}

// ============ MAIN FUNCTIONS ============

// Place an encrypted bid
function bid(einput encryptedAmount, bytes calldata inputProof) 
    public 
    auctionOngoing  // <-- This modifier runs first (checks auction is still open)
{
    // Don't allow someone to bid twice (keeps things simple)
    require(TFHE.isInitialized(bids[msg.sender]) == false, "Already placed a bid");
    // ^ TFHE.isInitialized checks if an encrypted value exists
    //   If they already have a bid stored, reject this transaction
    
    // Convert their encrypted input to a usable encrypted number
    euint64 encryptedBid = TFHE.asEuint64(encryptedAmount, inputProof);
    
    // Save their bid
    bids[msg.sender] = encryptedBid;
    
    // Add them to our list of bidders
    bidders.push(msg.sender);
    // ^ .push() adds to the end of an array
    
    // ============ THE MAGIC: ENCRYPTED COMPARISON ============
    
    // Compare: is this new bid greater than the current highest?
    // This comparison happens on ENCRYPTED data!
    ebool isHigher = TFHE.gt(encryptedBid, highestBid);
    // ^ "gt" = "greater than"
    // ^ Returns an ENCRYPTED boolean (we don't know if it's true or false!)
    
    // Update highest bid: pick the larger of the two
    // TFHE.select = "if condition is true, pick first value, else pick second"
    highestBid = TFHE.select(isHigher, encryptedBid, highestBid);
    // ^ If isHigher is true  → highestBid becomes encryptedBid
    //   If isHigher is false → highestBid stays the same
    //   ALL OF THIS HAPPENS ENCRYPTED - we never see the actual numbers!
    
    // Update highest bidder: pick the corresponding address
    eaddress encryptedSender = TFHE.asEaddress(msg.sender);
    // ^ Encrypt the current bidder's address
    
    highestBidder = TFHE.select(isHigher, encryptedSender, highestBidder);
    // ^ Same logic: if they're higher, they become the leader
    //   The contract doesn't know WHO is winning, just tracks it encrypted
    
    // Grant permissions for these encrypted values
    TFHE.allow(encryptedBid, address(this));
    TFHE.allow(highestBid, address(this));
    TFHE.allow(highestBidder, address(this));
    
    emit BidPlaced(msg.sender);
}

// End the auction and reveal ONLY the winner's address
function endAuction() public onlyAuctioneer auctionOngoing {
    // Mark auction as ended (no more bids allowed)
    auctionEnded = true;
    
    // ============ DECRYPTION REQUEST ============
    
    // Request decryption of the winner's address
    // This is the ONLY thing we decrypt - bid amounts stay secret forever!
    TFHE.allow(highestBidder, address(this));
    
    // Decrypt the winner's address
    // Note: In production, this would be async via a Gateway callback
    // For simplicity, we're showing the synchronous pattern
    winner = TFHE.decrypt(highestBidder);
    // ^ This reveals the actual address: "0xABC123..."
    //   But we NEVER decrypt highestBid - the amount stays hidden!
    
    emit AuctionEnded(winner);
    // ^ Publicly announce: "The winner is 0xABC123..."
    //   Nobody knows how much they bid, just that it was the highest
}

// ============ VIEW FUNCTIONS ============

// Check how many people have bid
function getBidderCount() public view returns (uint256) {
    return bidders.length;
    // ^ "view" = this function only reads data, doesn't change anything
}

// Check if a specific address has placed a bid
function hasBid(address user) public view returns (bool) {
    return TFHE.isInitialized(bids[user]);
}
How the winner selection works (the clever part):

Bidder A bids [encrypted: 50]  → Is 50 > 0?   YES → Leader: A, Amount: [encrypted: 50]
Bidder B bids [encrypted: 75]  → Is 75 > 50?  YES → Leader: B, Amount: [encrypted: 75]  
Bidder C bids [encrypted: 30]  → Is 30 > 75?  NO  → Leader: B, Amount: [encrypted: 75]
Bidder D bids [encrypted: 60]  → Is 60 > 75?  NO  → Leader: B, Amount: [encrypted: 75]
End auction → Decrypt winner's ADDRESS only → "0xB..."

The contract never knows the actual numbers! It just shuffles encrypted blobs around. Only at the very end do we reveal who won—never how much anyone bid.

Key privacy guarantees:

What	Revealed?
Winner's wallet address	✅ Yes (at auction end)
Winning bid amount	❌ No - stays encrypted forever
Losing bid amounts	❌ No - stays encrypted forever
Who participated	✅ Yes (from BidPlaced events)
