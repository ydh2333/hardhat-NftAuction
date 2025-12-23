// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract NFTAuctionV2 is Initializable, UUPSUpgradeable {
    // 结构体
    struct Auction {
        // 卖家
        address seller;
        // 拍卖持续时间
        uint256 duration;
        // 拍卖开始时间
        uint256 startTime;
        // 起始价格
        uint256 startPrice;
        // 是否结束
        bool ended;
        // 最高价格
        uint256 highestBid;
        // 最高出价者
        address highestBidder;
        // NFT合约地址
        address nftContract;
        // NFT ID
        uint256 nftId;
    }

    // 拍卖列表
    mapping(uint256 => Auction) public auctions;
    // 下一个拍卖ID
    uint256 public nextAuctionId;
    // 管理员地址
    address public admin;

    function initialize() public initializer {
        admin = msg.sender;
    }

    // 拍卖
    function createAuction(
        address _seller,
        uint256 _duration,
        uint256 _startPrice,
        address _nftContract,
        uint256 _nftId
    ) public {
        // 只有管理员可以创建拍卖
        require(msg.sender == admin, "Only admin can create an auction");
        // 检查参数
        require(_duration > 1000 * 8, "Duration must be greater than 8seconds");
        require(_startPrice > 0, "Start price must be greater than 0");

        IERC721(_nftContract).approve(address(this), _nftId);

        auctions[nextAuctionId] = Auction({
            seller: _seller,
            duration: _duration,
            startPrice: _startPrice,
            startTime: block.timestamp,
            ended: false,
            highestBid: 0,
            highestBidder: address(0),
            nftContract: _nftContract,
            nftId: _nftId
        });
        nextAuctionId++;
    }

    // 买家参与买单
    function placeBid(uint256 _auctionId) public payable {
        // 检查拍卖是否存在
        require(auctions[_auctionId].ended == false, "Auction is over");
        // 检查拍卖是否结束
        require(
            block.timestamp <
                auctions[_auctionId].startTime + auctions[_auctionId].duration,
            "Auction is over"
        );
        // 检查价格
        require(
            msg.value > auctions[_auctionId].highestBid &&
                msg.value > auctions[_auctionId].startPrice,
            "Bid price must be greater than current highest bid"
        );
        // 退回之前的最高出价
        if (auctions[_auctionId].highestBidder != address(0)) {
            (bool success, ) = auctions[_auctionId].highestBidder.call{
                value: auctions[_auctionId].highestBid
            }("");
            require(success, "Failed to refund previous highest bidder");
        }

        // 更新最高出价
        auctions[_auctionId].highestBid = msg.value;
        auctions[_auctionId].highestBidder = msg.sender;
    }

    // 结束拍卖
    function endAuction(uint256 _auctionId) public {
        Auction memory auction = auctions[_auctionId];
        // 只有管理员可以结束拍卖
        require(msg.sender == admin, "Only admin can end an auction");
        // 检查拍卖是否存在
        require(auction.ended == false, "Auction is over");
        // 检查拍卖是否结束
        require(
            block.timestamp < auction.startTime + auction.duration,
            "Auction is over"
        );
        // 转移NFT到价高者
        IERC721(auction.nftContract).transferFrom(
            address(this),
            auction.highestBidder,
            auction.nftId
        );
        // 转移资金到卖家
        payable(address(this)).transfer(address(this).balance);

        // 更新拍卖状态
        auction.ended = true;
    }

    function _authorizeUpgrade(address) internal view override {
        // 只有管理员可以升级合约
        require(msg.sender == admin, "Only admin can upgrade");
    }

    function testHello() public pure returns (string memory) {
        return "Hello, World!";
    }
}
