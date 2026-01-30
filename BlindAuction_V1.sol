// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Nhập thư viện phép thuật của Zama (FHE Library)
import "fhevm/lib/TFHE.sol";

contract BlindAuction {
    // ---------------------------------------------------------
    // 1. KHO CHỨA BÍ MẬT (State Variables)
    // ---------------------------------------------------------
    
    // Đây là "Cái Hộp Đen" lưu trữ giá thầu của từng người.
    // 'euint64' nghĩa là số nguyên đã được MÃ HÓA (Encrypted).
    // Người ngoài nhìn vào chỉ thấy rác dữ liệu, không thấy số tiền.
    mapping(address => euint64) private bids;

    // Sự kiện để thông báo ra ngoài: "Có ông này vừa đặt giá nè!"
    // (Nhưng đặt bao nhiêu thì KHÔNG báo)
    event BidPlaced(address indexed bidder);

    // ---------------------------------------------------------
    // 2. CHỨC NĂNG ĐẤU GIÁ (The Logic)
    // ---------------------------------------------------------

    // Hàm này nhận vào một "cục" dữ liệu đã mã hóa từ người dùng (einput)
    function bid(einput encryptedAmount, bytes calldata inputProof) public {
        
        // Bước 1: Chuyển đổi đầu vào thành dạng số mã hóa (euint64)
        // 'inputProof' là cái vé chứng minh người dùng mã hóa đúng chuẩn
        euint64 encryptedBid = TFHE.asEuint64(encryptedAmount, inputProof);

        // Bước 2: Cấp quyền cho Hợp đồng này được phép "xử lý" cái hộp đó
        // (Nếu không có dòng này, Hợp đồng chỉ giữ hộ chứ không so sánh được ai thắng)
        TFHE.allow(encryptedBid, address(this));

        // Bước 3: Lưu cái hộp vào kho, gắn tên người gửi (msg.sender)
        bids[msg.sender] = encryptedBid;

        // Bước 4: Bắn pháo hiệu thông báo đã nhận đơn
        emit BidPlaced(msg.sender);
    }
}
--------------------------------------------------------------------------------------
// SPDX-License-Identifier: MIT
// ^ This line tells everyone the license for this code (MIT = free to use)
pragma solidity ^0.8.24; // ^ This tells the compiler which version of Solidity to use

// Import the FHE magic from Zama's library import "fhevm/lib/TFHE.sol"; // ^ TFHE = "Fully Homomorphic Encryption" library // This lets us work with encrypted numbers without ever seeing the real values

contract BlindAuction { // ^ We're creating a new contract called "BlindAuction" // Think of a contract like a tiny program that lives on the blockchain

// This stores each person's encrypted bid // "address" = a user's wallet address (like their ID) // "euint64" = an ENCRYPTED 64-bit number (the "e" stands for encrypted) mapping(address => euint64) private bids; // ^ "mapping" is like a dictionary: look up a person, get their bid // "private" means other contracts can't peek at this directly

// This event announces when someone places a bid // (Events are like public announcements on the blockchain) event BidPlaced(address bidder); // ^ We only announce WHO bid, not HOW MUCH (that stays secret!)

// The main function: place an encrypted bid function bid(einput encryptedAmount, bytes calldata inputProof) public { // ^ "einput" = encrypted input from the user // ^ "inputProof" = proof that the encryption is valid // ^ "public" = anyone can call this function // ^ "calldata" = the data lives in a temporary, read-only space (cheaper gas)

// Convert the encrypted input into a usable encrypted number // and verify it's a legitimate encrypted value euint64 encryptedBid = TFHE.asEuint64(encryptedAmount, inputProof); // ^ This checks the proof and converts it to an encrypted 64-bit number // The contract NEVER sees the actual bid amount - it stays encrypted!

// Save this encrypted bid, linked to the sender's address bids[msg.sender] = encryptedBid; // ^ "msg.sender" = whoever called this function (the bidder) // We're storing their encrypted bid in our mapping

// Allow the contract to use this encrypted value in future computations TFHE.allow(encryptedBid, address(this)); // ^ This grants permission for the contract to do math on this encrypted number later // (like comparing bids to find the winner)

// Announce that a bid was placed (but not the amount!) emit BidPlaced(msg.sender); // ^ This creates a public log entry saying "this address placed a bid" } }

