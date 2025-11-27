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
    }

    event AuctionCreated(
        uint256 indexed auctionId,
        string itemName,
        uint256 startPrice
    );
    event BidPlaced(uint256 indexed auctionId, address bidder, uint256 amount);
    event AuctionEnded(
        uint256 indexed auctionId,
        address winner,
        uint256 amount
    );
    event TimeExtended(uint256 indexed auctionId, uint256 newEndTime);

    uint256 public auctionCount;
    mapping(uint256 => Auction) public auctions;

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
        a.highestBid = 0;
        a.highestBidder = address(0);
        a.endTime = block.timestamp + duration;
        a.ended = false;
        a.itemName = itemName;

        emit AuctionCreated(auctionId, itemName, startPrice);
        return auctionId;
    }

    function placeBid(uint256 auctionId) external payable {
        Auction storage a = auctions[auctionId];
        require(a.seller != address(0), "Auction not found");
        require(!a.ended, "Auction ended");
        require(block.timestamp < a.endTime, "Auction expired");

        uint256 minPrice = a.highestBid == 0 ? a.startPrice : a.highestBid;
        require(msg.value > minPrice, "Bid too low");

        address prevBidder = a.highestBidder;
        uint256 prevBid = a.highestBid;

        a.highestBidder = msg.sender;
        a.highestBid = msg.value;

        if (prevBidder != address(0) && prevBid > 0) {
            (bool ok, ) = payable(prevBidder).call{value: prevBid}("");
            require(ok, "Refund failed");
        }

        uint256 remaining = a.endTime > block.timestamp
            ? a.endTime - block.timestamp
            : 0;
        if (remaining <= 5 minutes) {
            a.endTime += 5 minutes;
            emit TimeExtended(auctionId, a.endTime);
        }

        emit BidPlaced(auctionId, msg.sender, msg.value);
    }

    function endAuction(uint256 auctionId) external {
        Auction storage a = auctions[auctionId];
        require(a.seller != address(0), "Auction not found");
        require(!a.ended, "Already ended");
        require(block.timestamp >= a.endTime, "Not ended yet");
        require(msg.sender == a.seller, "Only seller");

        a.ended = true;

        if (a.highestBid > 0) {
            (bool ok, ) = payable(a.seller).call{value: a.highestBid}("");
            require(ok, "Payout failed");
        }

        emit AuctionEnded(auctionId, a.highestBidder, a.highestBid);
    }

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
            string memory itemName
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
    }
}
