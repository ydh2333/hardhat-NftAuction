// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract NFTAuction is Initializable, UUPSUpgradeable {
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
        // 参与竞价的资产类型，0x地址表示eth，其他地址表示erc20
        address tokenAddress;
    }

    // 拍卖列表
    mapping(uint256 => Auction) public auctions;
    // 下一个拍卖ID
    uint256 public nextAuctionId;
    // 管理员地址
    address public admin;

    mapping(address => AggregatorV3Interface) public priceETHFeeds;

    function initialize() public initializer {
        admin = msg.sender;
    }

    function setPriceETHFeed(
        address _tokenAddress,
        address _priceETHFeed
    ) public {
        priceETHFeeds[_tokenAddress] = AggregatorV3Interface(_priceETHFeed);
    }

    // 创建拍卖，默认eth
    function createAuction(
        address _seller,
        uint256 _duration,
        uint256 _startPrice,
        address _nftContract,
        uint256 _nftId
    ) public {
        // 只有管理员可以创建拍卖
        require(msg.sender == admin, "Only admin can create an auction");
        // 检查参数,js脚本中单位是秒
        require(_duration > 8, "Duration must be greater than 8seconds");
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
            nftId: _nftId,
            tokenAddress: address(0)
        });
        nextAuctionId++;
    }

    // 买家参与买单
    function placeBid(
        uint256 _auctionId,
        uint256 _amount,
        address _tokenAddress
    ) public payable {
        Auction memory auction = auctions[_auctionId];
        // 检查拍卖是否存在
        require(auction.ended == false, "Auction is over");
        // 检查拍卖是否结束
        require(
            block.timestamp < auction.startTime + auction.duration,
            "Auction is over"
        );

        uint256 payvalue;
        if (_tokenAddress == address(0)) {
            _amount = msg.value;
        }


        // 当前竞价
        payvalue = _amount *
            uint256(getChainlinkDataFeedLatestAnswer(_tokenAddress));
        // 起拍价
        uint256 startPriceValue = auction.startPrice *
            uint256(getChainlinkDataFeedLatestAnswer(auction.tokenAddress));
        // 最高价
        uint256 highestBidValue = auction.highestBid *
            uint256(getChainlinkDataFeedLatestAnswer(auction.tokenAddress));
        // 检查价格
        require(
            payvalue >= startPriceValue && payvalue > highestBidValue,
            "Bid price must be greater than current highest bid"
        );

        // 检查是否是erc20资产
        if (_tokenAddress != address(0)) {
            // 转移erc20到合约
            IERC20(_tokenAddress).transferFrom(
                msg.sender,
                address(this),
                _amount
            );
        }
        // 退还逻辑，判断之前的最高者是什么资产
        if (auction.tokenAddress == address(0)) {
            // 退还之前的eth最高价
            // payable(auction.highestBidder).transfer(auction.highestBid);
            (bool success, ) = auction.highestBidder.call{
                value: auction.highestBid
            }("");
            require(success, "Failed to refund previous highest bidder");
        } else {
            // 退还之前的erc20最高价
            IERC20(auction.tokenAddress).transfer(
                auction.highestBidder,
                auction.highestBid
            );
        }

        // 更新最高出价
        auction.tokenAddress = _tokenAddress;
        auction.highestBid = _amount;
        auction.highestBidder = msg.sender;
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
            admin,
            auction.highestBidder,
            auction.nftId
        );
        // 转移资金到卖家
        payable(auction.seller).transfer(address(this).balance);

        // 更新拍卖状态
        auction.ended = true;
    }

    function _authorizeUpgrade(address) internal view override {
        // 只有管理员可以升级合约
        require(msg.sender == admin, "Only admin can upgrade");
    }

    function getChainlinkDataFeedLatestAnswer(
        address _tokenAddress
    ) public view returns (int256) {
        AggregatorV3Interface priceETHFeed = priceETHFeeds[_tokenAddress];
        // prettier-ignore
        (
        /* uint80 roundId */
        ,
        int256 answer,
        /*uint256 startedAt*/
        ,
        /*uint256 updatedAt*/
        ,
        /*uint80 answeredInRound*/
        ) = priceETHFeed.latestRoundData();
        return answer;
    }
}
