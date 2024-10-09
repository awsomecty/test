// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTSwap is Ownable {
    struct Order {
        uint256 tokenId;
        address payable seller;
        uint256 price;
        bool sold;
    }

    mapping(uint256 => Order) public orders;
    mapping(address => uint256[]) public userOrders;

    event OrderCreated(uint256 indexed tokenId, uint256 price, address seller);
    event OrderRevoked(uint256 indexed tokenId);
    event OrderUpdated(uint256 indexed tokenId, uint256 newPrice);
    event OrderPurchased(uint256 indexed tokenId, address buyer, uint256 price);

    modifier onlySeller(uint256 _tokenId) {
        require(orders[_tokenId].seller == msg.sender, "Not the seller");
        _;
    }

    modifier onlyUnsold(uint256 _tokenId) {
        require(!orders[_tokenId].sold, "This NFT has already been sold");
        _;
    }

    function list(ERC721 token, uint256 tokenId, uint256 price) public {
        require(token.ownerOf(tokenId) == msg.sender, "You are not the owner of this NFT");
        require(orders[tokenId].seller == address(0), "An order for this token already exists");

        orders[tokenId] = Order(tokenId, payable(msg.sender), price, false);
        userOrders[msg.sender].push(tokenId);

        emit OrderCreated(tokenId, price, msg.sender);
    }

    function revoke(uint256 tokenId) public onlySeller(tokenId) {
        delete orders[tokenId];
        uint256[] storage userOrderList = userOrders[msg.sender];
        for (uint i = 0; i < userOrderList.length; i++) {
            if (userOrderList[i] == tokenId) {
                userOrderList[i] = userOrderList[userOrderList.length - 1];
                userOrderList.pop();
                break;
            }
        }

        emit OrderRevoked(tokenId);
    }

    function update(uint256 tokenId, uint256 newPrice) public onlySeller(tokenId) {
        orders[tokenId].price = newPrice;

        emit OrderUpdated(tokenId, newPrice);
    }

    function purchase(uint256 tokenId) public payable onlyUnsold(tokenId) {
        Order memory order = orders[tokenId];
        require(msg.value >= order.price, "Not enough ether sent");

        (bool success, ) = order.seller.call{value: msg.value}("");
        require(success, "Transfer of ether failed");

        delete orders[tokenId];
        uint256[] storage userOrderList = userOrders[order.seller];
        for (uint i = 0; i < userOrderList.length; i++) {
            if (userOrderList[i] == tokenId) {
                userOrderList[i] = userOrderList[userOrderList.length - 1];
                userOrderList.pop();
                break;
            }
        }

        ERC721 token = ERC721(payable(address(token)));
        bool transferSuccess = token.transferFrom(order.seller, msg.sender, tokenId);
        require(transferSuccess, "Transfer of NFT failed");

        emit OrderPurchased(tokenId, msg.sender, msg.value);
    }
}