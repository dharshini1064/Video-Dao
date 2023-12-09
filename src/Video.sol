// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.20;

import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ERC721} from  "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {UserCenter} from "./UserCenter.sol";

contract Video is ERC721URIStorage {
    struct Advertisement {
        uint256 orderId;
        uint256 endTime;
    }
    
    UserCenter public userCenter;
    uint256 total;

    event AdvertisementAttached(uint256 tokenId, uint256 advertisementId);
    mapping(uint256=>Advertisement) attachedAdvertisement;
    address market;
    
    constructor(UserCenter userCenter_, address marketAddress_) ERC721("Vedio", "Vedio") {
        userCenter = userCenter_;
        market = marketAddress_;
    }

    function newVedio(string memory uri) public  {
        require(userCenter.userExist(msg.sender));

        uint256 tokenId = total++;
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, uri);
    }

    function reward(uint256 tokenId) external payable {
        address owner = ownerOf(tokenId);
        userCenter.income{value: msg.value}(owner);
    }

    function attachAdvertisement(uint256 tokenId, uint256 advertisementId, uint256 endTime) external  {
        require(msg.sender == market, "Vedio: only market can call");

        Advertisement storage ad  = attachedAdvertisement[tokenId];
        require(ad.endTime<block.timestamp);
        ad.orderId = advertisementId;
        ad.endTime = endTime;

        emit AdvertisementAttached(tokenId, advertisementId);
    }
}