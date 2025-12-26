// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract NFTAuctionV2 is Initializable, UUPSUpgradeable, IERC721Receiver {
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
        // 起始货币类型
        address startTokenAddress;
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

    mapping(address => AggregatorV3Interface) public priceFeeds;
    // 语言机小数位映射
    mapping(address => uint8) public priceFeedDecimals;

    // 创建拍卖事件
    event CreateAuction(
        uint256 indexed auctionId,
        address seller,
        uint256 duration,
        uint256 startPrice,
        address startTokenAddress,
        uint256 startTime,
        address nftContract,
        uint256 nftId,
        uint256 optTime
    );
    // 竞拍事件
    event PlaceBid(
        uint256 indexed auctionId,
        address bidder,
        uint256 amount,
        address tokenAddress,
        uint256 optTime
    );
    // 结束拍卖事件
    event EndAuction(
        uint256 indexed auctionId,
        address winner,
        uint256 amount,
        address tokenAddress,
        uint256 optTime
    );

    function initialize() public initializer {
        admin = msg.sender;
    }

    // eth:0x0000000000000000000000000000000000000000，0x694AA1769357215DE4FAC081bf1f309aDC325306
    // usdc:0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238，0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E
    function setPriceETHFeed(
        address _tokenAddress,
        address _priceFeedAddress
    ) public {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            _priceFeedAddress
        );
        priceFeeds[_tokenAddress] = priceFeed;
        priceFeedDecimals[_tokenAddress] = priceFeed.decimals(); // 存储小数位
    }

    // 实现 onERC721Received
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
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

        // 校验卖家是否已授权拍卖合约操作该 NFT
        IERC721 nftContract = IERC721(_nftContract);
        // 检查授权：合约被授权操作该 NFT 或者 _seller 是 NFT 所有者
        require(
            nftContract.getApproved(_nftId) == address(this) ||
                nftContract.ownerOf(_nftId) == _seller,
            "Auction contract not approved to transfer NFT"
        );

        nftContract.safeTransferFrom(_seller, address(this), _nftId);

        auctions[nextAuctionId] = Auction({
            seller: _seller,
            duration: _duration,
            startPrice: _startPrice,
            startTokenAddress: address(0), // 初始化默认为eth
            startTime: block.timestamp,
            ended: false,
            highestBid: 0,
            highestBidder: address(0),
            nftContract: _nftContract,
            nftId: _nftId,
            tokenAddress: address(0)
        });
        emit CreateAuction(
            nextAuctionId,
            _seller,
            _duration,
            _startPrice,
            address(0),
            block.timestamp,
            _nftContract,
            _nftId,
            block.timestamp
        );
        nextAuctionId++;
    }

    // 买家参与买单
    function placeBid(
        uint256 _auctionId,
        uint256 _amount,
        address _tokenAddress
    ) public payable {
        Auction storage auction = auctions[_auctionId];
        // 检查拍卖是否存在
        require(auction.ended == false, "Auction is over");
        // 检查拍卖是否结束
        require(
            block.timestamp < auction.startTime + auction.duration,
            "Auction is over"
        );

        if (_tokenAddress == address(0)) {
            require(_amount == msg.value, "ETH amount must match msg.value");
        }

        // 当前竞价
        uint256 payvalue = calculateValue(_amount, _tokenAddress);
        // 起拍价
        uint256 startPriceValue = calculateValue(
            auction.startPrice,
            auction.startTokenAddress
        );
        // 最高价
        uint256 highestBidValue = calculateValue(
            auction.highestBid,
            auction.tokenAddress
        );
        // 检查价格
        require(
            payvalue >= startPriceValue && payvalue > highestBidValue,
            "Bid price must be greater than current highest bid"
        );

        // 检查是否是erc20资产
        if (_tokenAddress != address(0)) {
            IERC20 token = IERC20(_tokenAddress);
            // 检查竞拍者已授权合约至少 _amount 数量的代币
            require(
                token.allowance(msg.sender, address(this)) >= _amount,
                "ERC20: Insufficient allowance"
            );
            // 转移erc20到合约
            token.transferFrom(msg.sender, address(this), _amount);
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

        emit PlaceBid(
            _auctionId,
            msg.sender,
            _amount,
            _tokenAddress,
            block.timestamp
        );
    }

    // 结束拍卖
    function endAuction(uint256 _auctionId) public {
        Auction storage auction = auctions[_auctionId];
        // 只有管理员可以结束拍卖
        require(msg.sender == admin, "Only admin can end an auction");
        // 检查拍卖是否存在
        require(auction.ended == false, "Auction is over");
        // 检查拍卖是否结束
        require(
            block.timestamp >= auction.startTime + auction.duration,
            "Auction is not end"
        );

        // 先更新拍卖状态
        auction.ended = true;
        // 如果流拍，退还NFT给卖家
        if (auction.highestBidder == address(0)) {
            IERC721(auction.nftContract).safeTransferFrom(
                address(this), // 合约是当前NFT所有者
                auction.seller,
                auction.nftId
            );
            return; // 无资金，直接返回
        }
        // 转移NFT到价高者
        IERC721(auction.nftContract).transferFrom(
            address(this),
            auction.highestBidder,
            auction.nftId
        );
        // 转移资金到卖家
        if (auction.tokenAddress == address(0)) {
            // 用ETH竞拍：转移对应金额（而非全部余额）
            (bool success, ) = auction.seller.call{value: auction.highestBid}(
                ""
            );
            require(success, "Failed to transfer ETH to seller");
        } else {
            // 用ERC20竞拍：转移对应数量的ERC20
            IERC20(auction.tokenAddress).transfer(
                auction.seller,
                auction.highestBid
            );
        }

        emit EndAuction(
            _auctionId,
            auction.highestBidder,
            auction.highestBid,
            auction.tokenAddress,
            block.timestamp
        );
    }

    function _authorizeUpgrade(address) internal view override {
        // 只有管理员可以升级合约
        require(msg.sender == admin, "Only admin can upgrade");
    }

    function getChainlinkDataFeedLatestAnswer(
        address _tokenAddress
    ) public view returns (int256) {
        AggregatorV3Interface priceFeed = priceFeeds[_tokenAddress];
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
        ) = priceFeed.latestRoundData();
        return answer;
    }

    function calculateValue(
        uint256 _amount,
        address _tokenAddress
    ) public view returns (uint256) {
        uint8 tokenDecimals;
        if (_tokenAddress == address(0)) {
            tokenDecimals = 18;
        } else {
            tokenDecimals = IERC20Metadata(_tokenAddress).decimals();
        }

        uint8 feedDecimals = priceFeedDecimals[_tokenAddress];
        int256 answer = getChainlinkDataFeedLatestAnswer(_tokenAddress);

        // 1、将_amount换算为18位小数
        uint256 amount18Dec = _amount * 10 ** (18 - tokenDecimals);
        // 2、将语言机换算为18位小数
        uint256 answer18Dec = uint256(answer) * 10 ** (18 - feedDecimals);
        // 3、计算实际价格
        return (amount18Dec * answer18Dec) / 10 ** 18;
    }

    function testHello() public pure returns (string memory) {
        return "Hello, World!";
    }
}
