const { deployments, upgrades, ethers } = require("hardhat")
const fs = require('fs');
const path = require('path');


module.exports = async ({ getNamedAccounts, deployments }) => {
    const { save } = deployments;
    const { deployer } = await getNamedAccounts();
    console.log("部署用户地址：", deployer);
    console.log("----------------------------------------------------------------------------")

    const storePath = path.resolve(__dirname, './.cache/proxyNftAuction.json');
    const data = JSON.parse(fs.readFileSync(storePath));
    console.log("代理合约地址：", data.proxyAddress);
    console.log("实现合约地址：", data.implementationAddress);


    const NFTAuctionV2 = await ethers.getContractFactory("NFTAuctionV2");
    const nftAuctionV2 = await upgrades.upgradeProxy(data.proxyAddress, NFTAuctionV2);
    await nftAuctionV2.waitForDeployment();
    const proxyAddressV2 = await nftAuctionV2.getAddress()
    // console.log("升级后代理合约地址：", proxyAddressV2);
    const implementationAddress = await upgrades.erc1967.getImplementationAddress(proxyAddressV2);
    console.log("实现合约地址V2：", implementationAddress);

    await save("NFTAuctionV2", {
        abi: NFTAuctionV2.interface.format('json'),
        address: proxyAddressV2
    });
}

module.exports.tags = ['deployNftAuctionV2']; 