const { deployments, upgrades, ethers } = require("hardhat")
const fs = require('fs');
const path = require('path');

// deploy/00_deploy_my_contract.js
module.exports = async ({ getNamedAccounts, deployments }) => {
    const { save } = deployments;
    const { deployer } = await getNamedAccounts();
    console.log("部署用户地址：", deployer);
    console.log("----------------------------------------------------------------------------")

    const NFTAuction = await ethers.getContractFactory("NFTAuction")

    // 通过代理合约部署，指定初始化函数
    const proxy = await upgrades.deployProxy(NFTAuction, [], { initializer: 'initialize' });
    await proxy.waitForDeployment();

    const proxyAddress = await proxy.getAddress()
    console.log("代理合约地址：", proxyAddress);
    const implementationAddress = await upgrades.erc1967.getImplementationAddress(proxyAddress);
    console.log("实现合约地址：", implementationAddress);

    const storePath = path.resolve(__dirname, './.cache/proxyNftAuction.json');

    fs.writeFileSync(storePath, JSON.stringify({
        proxyAddress,
        implementationAddress
    }));

    await save("NFTAuction", {
        abi: NFTAuction.interface.format('json'),
        address: proxyAddress
    });
};
module.exports.tags = ['deployNftAuction'];  