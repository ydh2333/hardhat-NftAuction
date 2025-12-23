const { ethers, deployments } = require("hardhat");
const { expect } = require("chai");

describe("AddERC721Test", function () {
    it("deploy.....", async function () {
        // 增加测试用例超时时间
        this.timeout(100000);
        const [account1, account2] = await ethers.getSigners();
        // 1、部署ERC721合约
        const MyNFTWithMetadata = await ethers.getContractFactory("MyNFTWithMetadata");
        const myNFTWithMetadata = await MyNFTWithMetadata.deploy();
        await myNFTWithMetadata.waitForDeployment();
        console.log("NFTcontract has been deployed succcessful, contract address is:", myNFTWithMetadata.target)

        // 铸造NFT
        for (let i = 0; i < 2; i++) {
            const tx = await myNFTWithMetadata.safeMint(
                account1.address,
                "https://ipfs.io/ipfs/QmQVjZSf6NtXrKXt8BzvUw9D1X4M7V4M5Yk6jy8RwP8g1"
            );
            await tx.wait();
            console.log("铸造成功");
        }
        console.log("getTotalSupply:", await myNFTWithMetadata.getTotalSupply());

        // 2、部署拍卖合约
        await deployments.fixture(["deployNftAuction"]);
        // 获取nft的代理。通过01_deploy_nft_auction.js的await save("NFTAuction" ...拿到
        const nftAuctionProxy = await deployments.get("NFTAuction");

        // 3、调用createAuction 创建拍卖
        // 先授权
        const approveTx = await myNFTWithMetadata
            .connect(account1) // 用所有者account1发起授权
            .setApprovalForAll(nftAuctionProxy.address, true); // 授权给拍卖合约
        await approveTx.wait();
        console.log(`已授权拍卖合约操作`);

        const nftAuction = await ethers.getContractAt("NFTAuction", nftAuctionProxy.address);
        await nftAuction.createAuction(
            account1.address,
            10,
            ethers.parseEther("0.0000000001"),
            myNFTWithMetadata.target,
            1
        )
        let auction = await nftAuction.auctions(0);
        console.log("createAuction success 01", auction);

        // 4、卖家参与竞价
        await nftAuction.connect(account2).placeBid(0, { value: ethers.parseEther("0.0000000002") });
        auction = await nftAuction.auctions(0);
        console.log("placeBid success 02", auction);

        // 5、结束拍卖
        await new Promise((resolve) => setTimeout(resolve, 8 * 1000))
        await nftAuction.connect(account1).endAuction(0);

        // 6、查看拍卖结果
        auction = await nftAuction.auctions(0);
        console.log("endAuction success 03", auction);
        expect(auction.highestBidder).to.equal(account2.address);
        expect(auction.highestBid).to.equal(ethers.parseEther("0.0000000002"));

        // 验证NFT所有权
        const owner = await myNFTWithMetadata.ownerOf(1)
        console.log("owner:", owner);
        expect(owner).to.equal(account2.address);
    });
});