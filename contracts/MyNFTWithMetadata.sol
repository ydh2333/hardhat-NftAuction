// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol"; // 新增：存储 tokenURI
import "@openzeppelin/contracts/access/Ownable.sol";

// 继承 ERC721URIStorage（包含 tokenURI 存储功能）
contract MyNFTWithMetadata is ERC721, ERC721URIStorage, Ownable {
    uint256 private _tokenIdCounter;

    constructor() ERC721("MyFirstNFT", "MFNFT") Ownable(msg.sender) {}

    // 铸造时指定元数据 URI
    function safeMint(address to, string memory uri) public onlyOwner {
        uint256 tokenId = _tokenIdCounter + 1;
        _tokenIdCounter = tokenId;
        _safeMint(to, tokenId);
        // 设置该 NFT 的元数据 URI
        _setTokenURI(tokenId, uri);
    }

    // 必须重写 tokenURI：因为 ERC721 和 ERC721URIStorage 都有该方法
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    // 必须重写 supportsInterface：实现接口检测
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function getTotalSupply() public view returns (uint256) {
        return _tokenIdCounter;
    }
}

// json的ipfs地址：https://crimson-elegant-landfowl-669.mypinata.cloud/ipfs/bafkreiegfscntxqoki365ui6uxk5i664rtf3jgyc23ra6bijtfkne43nq4