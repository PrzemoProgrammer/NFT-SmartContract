// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @author Przemek Murawski - <https://muranwebsite.web.app/>

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Goobyfaces is ERC721, Ownable {
    constructor(
        string memory _name,
        string memory _symbol
    ) ERC721(_name, _symbol) {}

    uint256 private tokenIdCounter = 0;
    bool private mintingExecuted = false;
    uint256 tokenPriceOnStart = 20 * 1e18;

    mapping(uint256 => address) private tokenOwners;
    mapping(address => uint256) private ownerTokenCount;
    mapping(uint256 => string) private tokenURIs;
    mapping(uint256 => uint256) private tokenPrices;
    mapping(uint256 => bool) private tokensForSale;

    event TokensPurchased(address indexed buyer, uint256 indexed tokenId);
    event TokenListedForSale(uint256 indexed tokenId, uint256 price);

    function mint(address _to) external onlyOwner {
        uint256 newTokenId = tokenIdCounter;
        tokenIdCounter++;

        _mint(_to, newTokenId);
    }

    function totalSupply() external view returns (uint256) {
        return ownerTokenCount[address(this)];
    }

    function ownerOf(
        uint256 tokenId
    ) public view virtual override returns (address) {
        return tokenOwners[tokenId];
    }

    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        return tokenURIs[tokenId];
    }

    function balanceOf(
        address owner
    ) public view virtual override returns (uint256) {
        return ownerTokenCount[owner];
    }

    function setTokenPrice(uint256 tokenId, uint256 price) public onlyOwner {
        tokenPrices[tokenId] = price;
    }

    function getTokenPrice(uint256 tokenId) external view returns (uint256) {
        return tokenPrices[tokenId];
    }

    function transfer(address to, uint256 tokenId) external {
        require(
            tokenOwners[tokenId] == msg.sender,
            "You can only transfer your own tokens"
        );
        _transfer(msg.sender, to, tokenId);
    }

    function approve(address to, uint256 tokenId) public virtual override {
        require(
            tokenOwners[tokenId] == msg.sender,
            "You can only approve your own tokens"
        );
        _approve(to, tokenId);
    }

    function getApproved(
        uint256 tokenId
    ) public view virtual override returns (address) {
        require(tokenOwners[tokenId] != address(0), "Token does not exist");
        return tokenApprovals[tokenId];
    }

    function setApprovalForAll(
        address operator,
        bool approved
    ) public virtual override {
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(
        address owner,
        address operator
    ) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function mintBatchWithMetadata(
        uint256[] memory tokenIds,
        string[] memory _tokenURIs
    ) external onlyOwner {
        require(!mintingExecuted, "Minting already executed");
        require(
            tokenIds.length == _tokenURIs.length,
            "Array lengths do not match"
        );

        for (uint256 i = 0; i < tokenIds.length; i++) {
            _mintToken(tokenIds[i], _tokenURIs[i]);
            setTokenPrice(tokenIds[i], tokenPriceOnStart);
            listTokenForSale(tokenIds[i], tokenPriceOnStart);
        }

        mintingExecuted = true;
    }

    function _mintToken(uint256 tokenId, string memory uri) internal {
        tokenOwners[tokenId] = owner();
        tokenURIs[tokenId] = uri;
        ownerTokenCount[owner()]++;
        emit Transfer(address(0), owner(), tokenId);
    }

    function listTokenForSale(uint256 tokenId, uint256 price) public {
        require(
            msg.sender == tokenOwners[tokenId],
            "You can only list your own tokens for sale"
        );
        require(price > 0, "Price must be greater than 0");

        tokenPrices[tokenId] = price;
        tokensForSale[tokenId] = true;

        emit TokenListedForSale(tokenId, price);
    }

    function purchaseToken(uint256 tokenId) external payable {
        require(bytes(tokenURIs[tokenId]).length > 0, "Invalid tokenId");
        require(tokensForSale[tokenId], "Token is not available for purchase");

        uint256 tokenPrice = tokenPrices[tokenId];
        require(tokenPrice > 0, "Token price not set");
        require(msg.value >= tokenPrice, "Insufficient ETH sent");

        address previousOwner = tokenOwners[tokenId];
        tokenOwners[tokenId] = msg.sender;
        tokensForSale[tokenId] = false;

        ownerTokenCount[previousOwner]--;
        ownerTokenCount[msg.sender]++;

        (bool success, ) = previousOwner.call{value: tokenPrice}("");
        require(success, "ETH transfer to previous owner failed");

        emit Transfer(previousOwner, msg.sender, tokenId);
        emit TokensPurchased(msg.sender, tokenId);
    }

    function getTokenURIForSale(
        uint256 tokenId
    ) external view returns (string memory) {
        require(tokensForSale[tokenId], "Token is not available for purchase");
        return tokenURIs[tokenId];
    }

    mapping(uint256 => address) private tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        require(to != address(0), "Transfer to zero address not allowed");
        require(tokenOwners[tokenId] == from, "Sender does not own the token");
        require(!_isContract(to), "Receiver cannot be a contract");

        tokenOwners[tokenId] = to;
        ownerTokenCount[from]--;
        ownerTokenCount[to]++;

        emit Transfer(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        require(
            msg.sender == from ||
                tokenApprovals[tokenId] == msg.sender ||
                _operatorApprovals[tokenOwners[tokenId]][msg.sender],
            "Not authorized to transfer"
        );

        _transfer(from, to, tokenId);
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        require(
            msg.sender == from ||
                tokenApprovals[tokenId] == msg.sender ||
                _operatorApprovals[tokenOwners[tokenId]][msg.sender],
            "Not authorized to transfer"
        );

        require(tokenOwners[tokenId] == from, "Sender does not own the token");

        _transfer(from, to, tokenId);
    }

    function _approve(address to, uint256 tokenId) internal virtual override {
        tokenApprovals[tokenId] = to;
        emit Approval(tokenOwners[tokenId], to, tokenId);
    }

    function _isContract(address addr) private view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }
}
