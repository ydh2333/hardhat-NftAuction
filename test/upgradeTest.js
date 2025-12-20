
const { ethers, deployments } = require("hardhat");
const { expect } = require("chai");

describe("upgrade test", function () {
    it("deploy.....", async function () {
        // 1、部署合约
        await deployments.fixture(["deployNftAuction"]);
        // 获取nft的代理。通过01_deploy_nft_auction.js的await save("NFTAuction" ...拿到
        const nftAuctionProxy = await deployments.get("NFTAuction");
        // 2、调用createAuction 创建拍卖
        const nftAuction = await ethers.getContractAt("NFTAuction", nftAuctionProxy.address);
        const [account1] = await ethers.getSigners();
        await nftAuction.createAuction(
            account1.address,
            100 * 1000,
            ethers.parseEther("0.0000000001"),
            ethers.ZeroAddress,
            1
        )
        const auction = await nftAuction.auctions(0);
        console.log("createAuction success", auction);

        const implementationAddress = await upgrades.erc1967.getImplementationAddress(nftAuctionProxy.address);
        console.log("实现合约地址V1：", implementationAddress);
        // 3、升级合约
        await deployments.fixture(["deployNftAuctionV2"]);

        const implementationAddress2 = await upgrades.erc1967.getImplementationAddress(nftAuctionProxy.address);
        console.log("实现合约地址V2：", implementationAddress2);


        const nftAuctionV2 = await ethers.getContractAt("NFTAuctionV2", nftAuctionProxy.address);
        // 4、读取合约的auction[0]
        const auction2 = await nftAuctionV2.auctions(0);

        // 5、运行一下新方法
        const hello = await nftAuctionV2.testHello();
        console.log("this is hello::::::::::", hello)

        // console.log("createAuction success", auction2);
        expect(auction2.startTime).to.equal(auction.startTime)
        expect(implementationAddress2).to.not.equal(implementationAddress)


    })








});