// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.20;
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {UserCenter} from "./UserCenter.sol";

interface IVedioAdvertisement {
    function attachAdvertisement(uint256 tokenId, uint256 advertisementId, uint256 endTime) external;
}

contract Market  {
    enum OrderStatus {
        Default,
        Listing,
        Executed,
        Canceled
    }
    
    struct SellOrder {
        uint256 id;
        address owner;
        address nftAddress;
        uint256 tokenId;

        uint256 price; // only support native currency now
        OrderStatus status;
    }

    struct Advertisement {
        uint256 id;
        address owner;

        address targetNftAddress;
        uint256 targetTokenId;
        uint256 pay;
        string uri;
        uint256 showDuration;
        OrderStatus status;
    }

    event SellOrderCreated(uint256 indexed orderId);

    uint256 totalSellOrders;
    mapping(uint256=>SellOrder) public sellOrders;

    uint256 totalAdvertisements;
    mapping(uint256=>Advertisement) public advertisements;

    UserCenter public userCenter;
    
    constructor(UserCenter userCenter_) {
        userCenter = userCenter_;
    }

    function list(address nftAddress, uint256 tokenId, uint256 price) external {
        require(IERC721(nftAddress).ownerOf(tokenId) == msg.sender, "Market: Not owner Of NFT");
        uint256 orderId = ++totalSellOrders;

        SellOrder storage order = sellOrders[orderId];
        order.id = orderId;
        order.owner = msg.sender;
        order.nftAddress = nftAddress;
        order.tokenId = tokenId;
        order.price = price;

        //modify status
        order.status = OrderStatus.Listing;
    }

    function cancel(uint256 orderId) external {
        SellOrder storage order = sellOrders[orderId];
        require(order.owner == msg.sender, "Makert: Not owner of Order");
        require(order.status == OrderStatus.Listing, "Market: Order not listing");

        //modify status
        order.status = OrderStatus.Canceled;
    }

    function buy(uint256 orderId) external payable {
        SellOrder storage order = sellOrders[orderId];
        require(order.status == OrderStatus.Listing, "Market: Order not listing");
        require(order.price>msg.value, "Market: msg.value is too low");

        IERC721(order.nftAddress).transferFrom(address(this), msg.sender, order.tokenId);
        userCenter.income{value: msg.value}(order.owner);

        //modify status
        order.status = OrderStatus.Executed;
    }

    
    function listAdvertisement(address targetNftAddress, uint256 targetTokenId, uint256 showDuration) external payable {
        require(IERC721(targetNftAddress).ownerOf(targetTokenId)!=address(0));

        uint256 advertisementId = ++totalAdvertisements;
        Advertisement storage advertisement = advertisements[advertisementId];

        advertisement.owner = msg.sender;
        advertisement.pay = msg.value;
        advertisement.showDuration = showDuration;
        advertisement.targetNftAddress = targetNftAddress;
        advertisement.targetTokenId = targetTokenId;

        // modify status
        advertisement.status = OrderStatus.Listing;
    }

    function acceptAdvertisemnt(uint256 advertisementId) external {
        Advertisement storage advertisement = advertisements[advertisementId];
        require(advertisement.status == OrderStatus.Listing);

        require(IERC721(advertisement.targetNftAddress).ownerOf(advertisement.targetTokenId) == msg.sender, 
            "Market: Only owner of vedio can accept advertisemnt");
        // owner of vedio can get payment
        userCenter.income{value: advertisement.pay}(msg.sender);
        
        // modify status
        advertisement.status = OrderStatus.Executed;
    }

    function cancelAdvertisement(uint256 advertisementId) external {
        Advertisement storage advertisement = advertisements[advertisementId];
        require(advertisement.status == OrderStatus.Listing);
        require(advertisement.owner == msg.sender, "Market: Only owner of advertisemnt can cancel");
        // refund
        payable(msg.sender).transfer(advertisement.pay);

         // modify status
        advertisement.status = OrderStatus.Canceled;
    }
}