const { ethers, deployments } = require("hardhat");
const { expect } = require("chai");

describe("NFTAuctionTest", function () {
    let account1, account2, account3, account4;
    let myNFTWithMetadata, nftAuctionProxy, nftAuction;

    this.timeout(150000);

    before(async function () {
        await deployments.fixture(["MyNFTWithMetadata", "deployNftAuction"]);
        [account1, account2, account3, account4] = await ethers.getSigners();
        console.log("account1 address::::", account1.address)

        const MyNFTWithMetadata = await deployments.get("MyNFTWithMetadata");
        myNFTWithMetadata = await ethers.getContractAt("MyNFTWithMetadata", MyNFTWithMetadata.address);

        nftAuctionProxy = await deployments.get("NFTAuction");
        nftAuction = await ethers.getContractAt("NFTAuction", nftAuctionProxy.address);

        nftAuction.setPriceETHFeed("0x0000000000000000000000000000000000000000", "0x694AA1769357215DE4FAC081bf1f309aDC325306")
        nftAuction.setPriceETHFeed("0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238", "0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E")
    })



    it("Create NFT", async function () {
        // 铸造NFT
        const tx = await myNFTWithMetadata.safeMint(
            account1.address,
            "https://ipfs.io/ipfs/QmQVjZSf6NtXrKXt8BzvUw9D1X4M7V4M5Yk6jy8RwP8g1"
        );
        await tx.wait();
        console.log("铸造成功...");

        const totalSupply = await myNFTWithMetadata.getTotalSupply();
        console.log("getTotalSupply:", totalSupply);
        expect(totalSupply).to.equal(1);
    });


    it("Approve NFTAuction", async function () {
        const approveTx = await myNFTWithMetadata
            .connect(account1) // 用所有者account1发起授权
            .setApprovalForAll(nftAuctionProxy.address, true); // 授权给拍卖合约
        await approveTx.wait();
        console.log(`已授权拍卖合约操作`);
        expect(await myNFTWithMetadata.isApprovedForAll(account1.address, nftAuctionProxy.address)).to.equal(true);
    });

    it("Create Auction", async function () {
        const createAuctionTx = await nftAuction.createAuction(
            account1.address,
            120,
            ethers.parseEther("0.00000000000000001"),
            myNFTWithMetadata.target,
            1
        )
        await createAuctionTx.wait();
        let auction = await nftAuction.auctions(0);
        console.log("createAuction success 01", auction);
        expect(auction.seller).to.equal(account1.address);
    });

    it("Place Bid", async function () {
        const placeBidTx = await nftAuction.connect(account2).placeBid(0, 10, ethers.ZeroAddress, { value: ethers.parseEther("0.00000000000000001") });
        placeBidTx.wait();
        let auction = await nftAuction.auctions(0);
        console.log("placeBid success 02", auction);
        // await new Promise(resolve => setTimeout(resolve, 10000));
        expect(auction.highestBidder).to.equal(account2.address);
        expect(auction.highestBid).to.equal(ethers.parseEther("0.00000000000000001"));

        const placeBidTx2 = await nftAuction.connect(account3).placeBid(0, 30, ethers.ZeroAddress, { value: ethers.parseEther("0.00000000000000003") });
        placeBidTx2.wait();
        auction = await nftAuction.auctions(0);
        // await new Promise(resolve => setTimeout(resolve, 10000));
        console.log("placeBid success 03", auction);
        expect(auction.highestBidder).to.equal(account3.address);
        expect(auction.highestBid).to.equal(ethers.parseEther("0.00000000000000003"));
    });

    it("Place Bid with USDC and ETH", async function () {
        // 授权使用usdc
        await approveUSDC("0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238", nftAuctionProxy.address, 100, account1);
        await approveUSDC("0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238", nftAuctionProxy.address, 100, account4);

        // const usdcContract = new ethers.Contract(
        //     "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238",
        //     ["function balanceOf(address) view returns (uint256)"], // USDC的balanceOf接口
        //     ethers.provider
        // );
        // // 查询account1的USDC余额（注意USDC是6位小数，需除以1e6转换为可读单位）
        // const balance = ethers.formatUnits(await usdcContract.balanceOf(account1.address), 6);
        // console.log("account1的USDC余额:::::::::::::::::::::::::::", balance);


        await nftAuction.connect(account1).placeBid(0, 5, "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238");
        let auction = await nftAuction.auctions(0);
        // await new Promise(resolve => setTimeout(resolve, 15000));
        console.log("placeBid success 01", auction);
        expect(auction.highestBidder).to.equal(account1.address);
        expect(auction.highestBid).to.equal(5);

        await nftAuction.connect(account4).placeBid(0, 10, "0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238");
        auction = await nftAuction.auctions(0);
        // await new Promise(resolve => setTimeout(resolve, 15000));
        console.log("placeBid success 04", auction);
        expect(auction.highestBidder).to.equal(account4.address);
        expect(auction.highestBid).to.equal(10);
    });

    it("End Auction", async function () {
        console.log("等待拍卖时间结束...");
        await new Promise(resolve => setTimeout(resolve, 100000)); // 等待100秒

        const endAuctionTx = await nftAuction.endAuction(0);
        await endAuctionTx.wait();
        let auction = await nftAuction.auctions(0);
        console.log("endAuction success", auction);
        expect(auction.ended).to.equal(true);

        // 验证NFT所有权
        const owner = await myNFTWithMetadata.ownerOf(1);
        expect(owner).to.equal(account4.address);
    });

    /**
    * USDC授权函数
    * @param {string} usdcAddress USDC合约地址
    * @param {string} spender 被授权的合约地址（如拍卖合约）
    * @param {number} amount 授权金额（USDC，整数）
    * @param {Signer} signer 授权账号的Signer
    * @returns {Promise<TransactionReceipt>} 交易回执
    */
    async function approveUSDC(usdcAddress, spender, amount, signer) {
        const erc20Abi = ["function approve(address spender, uint256 amount) external returns (bool)"];
        const usdcContract = await ethers.getContractAt(erc20Abi, usdcAddress, signer);

        // 转换为USDC最小单位（6位小数）
        const approveAmount = ethers.parseUnits(amount.toString(), 6);

        const tx = await usdcContract.approve(spender, approveAmount);
        const receipt = await tx.wait();
        console.log(`USDC授权成功：${amount} USDC，交易哈希：${receipt.hash}`);
        return receipt;
    }
});
