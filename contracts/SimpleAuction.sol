// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract SimpleAuction {
    struct Auction {
        address seller;
        uint256 startPrice;
        uint256 highestBid;
        address highestBidder;
        uint256 endTime;
        bool ended;
        string itemName;
        bool claimed;
    }

    struct AuctionRecord {
        uint256 auctionId;
        string itemName;
        uint256 finalPrice;
        uint256 timestamp;
    }

    event AuctionCreated(
        uint256 indexed auctionId,
        string itemName,
        uint256 startPrice
    );
    event BidPlaced(uint256 indexed auctionId, address bidder, uint256 amount);
    event BidRefunded(
        uint256 indexed auctionId,
        address bidder,
        uint256 amount
    );
    event AuctionEnded(
        uint256 indexed auctionId,
        address winner,
        uint256 amount
    );
    event TimeExtended(uint256 indexed auctionId, uint256 newEndTime);
    event FundsClaimed(
        uint256 indexed auctionId,
        address seller,
        uint256 amount
    );

    uint256 public auctionCount;
    mapping(uint256 => Auction) public auctions;
    mapping(address => AuctionRecord[]) public userRecords;

    /**
     * @dev Creates a new auction.
     * @param itemName The name of the item being auctioned.
     * @param startPrice The starting price of the auction.
     * @param duration The duration of the auction in seconds.
     * @return The ID of the created auction. */
    function createAuction(
        string memory itemName,
        uint256 startPrice,
        uint256 duration
    ) external returns (uint256) {
        require(bytes(itemName).length > 0, "Invalid itemName");
        require(duration > 0, "Invalid duration");

        uint256 auctionId = ++auctionCount;
        Auction storage a = auctions[auctionId];
        a.seller = msg.sender;
        a.startPrice = startPrice;
        a.highestBid = startPrice;
        a.highestBidder = address(0);
        a.endTime = block.timestamp + duration;
        a.ended = false;
        a.itemName = itemName;
        a.claimed = false;

        emit AuctionCreated(auctionId, itemName, startPrice);
        return auctionId;
    }

    /**
     * @dev Places a bid on an auction.
     * @param auctionId The ID of the auction to bid on.
     */
    function placeBid(uint256 auctionId) external payable {
        Auction storage a = auctions[auctionId];
        require(a.seller != address(0), "Auction not found");
        require(!a.ended, "Auction ended");
        require(block.timestamp < a.endTime, "Auction expired");
        require(msg.sender != a.seller, "Seller cannot bid");
        require(msg.value > a.highestBid, "Bid too low");

        address prevBidder = a.highestBidder;
        uint256 prevBid = a.highestBid;

        a.highestBidder = msg.sender;
        a.highestBid = msg.value;

        if (prevBidder != address(0)) {
            (bool ok, ) = payable(prevBidder).call{value: prevBid}("");
            require(ok, "Refund failed");
            emit BidRefunded(auctionId, prevBidder, prevBid);
        }

        uint256 remaining = a.endTime > block.timestamp
            ? a.endTime - block.timestamp
            : 0;
        if (remaining <= 1 minutes) {
            a.endTime += 1 minutes;
            emit TimeExtended(auctionId, a.endTime);
        }

        emit BidPlaced(auctionId, msg.sender, msg.value);
    }

    // 拍卖结束并自动结算（任何人都可以调用）
    function endAuction(uint256 auctionId) external {
        Auction storage a = auctions[auctionId];
        require(a.seller != address(0), "Auction not found");
        require(!a.ended, "Already ended");
        require(block.timestamp >= a.endTime, "Not ended yet");

        a.ended = true;

        if (a.highestBidder != address(0)) {
            // 记录赢家历史
            userRecords[a.highestBidder].push(
                AuctionRecord({
                    auctionId: auctionId,
                    itemName: a.itemName,
                    finalPrice: a.highestBid,
                    timestamp: block.timestamp
                })
            );

            // 自动转账给卖家
            a.claimed = true;
            (bool ok, ) = payable(a.seller).call{value: a.highestBid}("");
            require(ok, "Payout failed");
            emit FundsClaimed(auctionId, a.seller, a.highestBid);
        }

        emit AuctionEnded(auctionId, a.highestBidder, a.highestBid);
    }

    // 获取拍卖信息
    function getAuction(
        uint256 auctionId
    )
        external
        view
        returns (
            address seller,
            uint256 startPrice,
            uint256 highestBid,
            address highestBidder,
            uint256 endTime,
            bool ended,
            string memory itemName,
            bool claimed
        )
    {
        Auction storage a = auctions[auctionId];
        require(a.seller != address(0), "Auction not found");
        seller = a.seller;
        startPrice = a.startPrice;
        highestBid = a.highestBid;
        highestBidder = a.highestBidder;
        endTime = a.endTime;
        ended = a.ended;
        itemName = a.itemName;
        claimed = a.claimed;
    }

    // 获取用户拍卖记录
    function getUserRecords(
        address user
    ) external view returns (AuctionRecord[] memory) {
        return userRecords[user];
    }

    // 获取用户拍卖记录数量
    function getUserRecordCount(address user) external view returns (uint256) {
        return userRecords[user].length;
    }

    // 取消拍卖
    function cancelAuction(uint256 auctionId) external {
        Auction storage a = auctions[auctionId];
        require(msg.sender == a.seller, "Only seller can cancel");
        require(a.highestBidder == address(0), "Cannot cancel with bids");
        require(!a.ended, "Already ended");
        a.ended = true;
        emit AuctionEnded(auctionId, address(0), 0);
    }
}
