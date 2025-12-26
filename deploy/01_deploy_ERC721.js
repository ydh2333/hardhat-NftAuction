const { deployments, upgrades, ethers } = require("hardhat")
const fs = require('fs');
const path = require('path');

module.exports = async ({ getNamedAccounts, deployments }) => {
    const { save } = deployments;

    const MyNft721 = await ethers.getContractFactory("MyNFTWithMetadata");
    const myNFTWithMetadata = await MyNft721.deploy();
    await myNFTWithMetadata.waitForDeployment();

    console.log("MyNFTWithMetadata has been deployed succcessful, contract address is:", myNFTWithMetadata.target)

    await save("MyNFTWithMetadata", {
        abi: MyNft721.interface.format('json'),
        address: myNFTWithMetadata.target
    });


}
module.exports.tags = ['MyNFTWithMetadata'];  