// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AyaMarket is ReentrancyGuard {
    // === ENUMS ===//
    enum Category {
        GRAINS_PACKAGED,     // 1 (Rice, beans, garri)
        CRAFTS_ART,          // 2 (Beaded jewelry, paintings)
        FASHION,             // 3 (Ankara clothing, caps)
        HOME_DECOR           // 4(Woven mats, pottery)
    }

    // === STRUCTS ===//
       struct Product {
        uint256 id;
        address seller;
        string name;
        Category category;
        uint256 price;
        bool isAvailable;
        string details; // IPFS hash for images/descriptions
    }

    struct Order {
        uint256 productId;
        address buyer;
        uint256 amountPaid;
        bool isConfirmed;
        uint256 timestamp;
    }

    // === STATE VARIABLES ===//
    mapping(uint256 => Product) public products;
    mapping(uint256 => Order) public orders;
    mapping(address => uint256) public reputationPoints; // Aya Points
    mapping(address => uint256[]) public sellerProducts; // Track products by seller

    uint256 public productCounter;
    uint256 public orderCounter;
    IERC20 public stablecoin;
    address public owner;

    // === EVENTS ===//
    event ProductListed(uint256 indexed productId, Category indexed category, address indexed seller);
    event OrderPlaced(uint256 indexed orderId, address indexed buyer, uint256 productId);
    event OrderConfirmed(uint256 indexed orderId, address indexed seller);
    event ReputationUpdated(address indexed user, uint256 newPoints);

    // ====  MODIFIERS ===//
        modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    // === CONSTRUCTOR ===//
    constructor(address _stablecoinAddress) {
        stablecoin = IERC20(_stablecoinAddress);
        owner = msg.sender;
    }

    // === CORE FUNCTIONS ===//
    function listProduct(
        string memory _name,
        Category _category,
        uint256 _price,
        string memory _details
    ) external {
        productCounter++;
        products[productCounter] = Product(
            productCounter,
            msg.sender,
            _name,
            _category,
            _price,
            true,
            _details
        );
        sellerProducts[msg.sender].push(productCounter);
        emit ProductListed(productCounter, _category, msg.sender);
    }

    function placeOrder(uint256 _productId) external nonReentrant {
        Product storage product = products[_productId];
        require(product.isAvailable, "Product unavailable");
        require(stablecoin.allowance(msg.sender, address(this)) >= product.price, "Allowance insufficient");

        stablecoin.transferFrom(msg.sender, address(this), product.price);
        product.isAvailable = false;

        orderCounter++;
        orders[orderCounter] = Order(
            _productId,
            msg.sender,
            product.price,
            false,
            block.timestamp
        );
        emit OrderPlaced(orderCounter, msg.sender, _productId);
    }

    function confirmDelivery(uint256 _orderId) external nonReentrant {
        Order storage order = orders[_orderId];
        Product memory product = products[order.productId];

        require(msg.sender == order.buyer, "Only buyer can confirm");
        require(!order.isConfirmed, "Order already completed");

        stablecoin.transfer(product.seller, order.amountPaid);
        order.isConfirmed = true;

        _updateReputation(product.seller, 20); // Seller earns more
        _updateReputation(msg.sender, 10);    // Buyer earns points

        emit OrderConfirmed(_orderId, product.seller);
    }

    // === UTILITY FUNCTIONS ===//
    function _updateReputation(address _user, uint256 _points) private {
        reputationPoints[_user] += _points;
        emit ReputationUpdated(_user, reputationPoints[_user]);
    }

    function getProductsByCategory(Category _category) external view returns (Product[] memory) {
        uint256 count;
        for (uint256 i = 1; i <= productCounter; i++) {
            if (products[i].category == _category) count++;
        }

        Product[] memory result = new Product[](count);
        uint256 index;
        for (uint256 i = 1; i <= productCounter; i++) {
            if (products[i].category == _category) {
                result[index] = products[i];
                index++;
            }
        }
        return result;
    }

    function getSellerProducts(address _seller) external view returns (Product[] memory) {
        uint256[] memory productIds = sellerProducts[_seller];
        Product[] memory result = new Product[](productIds.length);
        for (uint256 i = 0; i < productIds.length; i++) {
            result[i] = products[productIds[i]];
        }
        return result;
    }
}