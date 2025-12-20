
// const {ethers} = require("hardhat");

// describe("Starting", function () {
//     it("deploy.....", async function () {
//         const [account1, account2] = await ethers.getSigners();

//         const NFTAuction = await ethers.getContractFactory("NFTAuction");
//         const nftAuction = await NFTAuction.deploy();
//         await nftAuction.waitForDeployment();
//         console.log("contract has been deployed succcessful, contract address is:", nftAuction.target)


//         await nftAuction.createAuction(
//             account1.address,
//             100*1000,
//             ethers.parseEther("0.00000000000000001"),
//             ethers.ZeroAddress,
//             0
//         );

//         const auction = await nftAuction.auctions(0);
//         console.log("auction:", auction);
//     });


// });