// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract BlindBox is ERC721 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    uint256 private _totalSupply;
    uint256 public maxBlindBoxes = 100;
    uint256 public pricePerBlindBox = 1 ether;

    constructor(string memory name, string memory symbol, uint256 _maxBlindBoxes, uint256 _pricePerBlindBox) payable ERC721(name, symbol) {
        _totalSupply = _maxBlindBoxes;
        maxBlindBoxes = _maxBlindBoxes;
        pricePerBlindBox = _pricePerBlindBox;
        _owner = msg.sender;
    }

    function buyBlindBox() public payable returns (uint256, uint256, string memory) {
        require(_tokenIds.current() < maxBlindBoxes, "No more blind boxes available");
        require(msg.value >= pricePerBlindBox * 1 ether, "Insufficient funds");

        // Get a random NFT type ID
        uint256 typeId = _getRandomNftTypeId();

        // Get the description of the NFT type
        string memory typeDescription = _nftTypeDescriptions[typeId];

        // Mint the NFT
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        _safeMint(msg.sender, newTokenId);

        // Decrease the remaining supply of the NFT type
        _nftRemainingSupply[typeId]--;

        // Update the total supply
        _totalSupply--;

        // Return the minted NFT token ID and type ID
        return (newTokenId, typeId, typeDescription);
    }

    function _getRandomNftTypeId() private view returns (uint256) {
        uint256 randomNumber = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender)));
        uint256 index = randomNumber % _nftTypes.length;
        return _nftTypes[index].typeId;
    }

    function setMaxBlindBoxes(uint256 _maxBlindBoxes) public onlyOwner {
        require(_maxBlindBoxes >= _tokenIds.current(), "New maxBlindBoxes must be greater than or equal to the number of BlindBoxes already minted.");
        maxBlindBoxes = _maxBlindBoxes;
        _totalSupply = maxBlindBoxes - _tokenIds.current();
    }

    address private _owner;

    modifier onlyOwner() {
        require(msg.sender == owner(), "Only owner can perform this action.");
        _;
    }

    function owner() public view returns (address) {
        return _owner;
    }

    mapping(address => uint256) public balances;

    function withdraw(uint256 amountInEther) public onlyOwner {
    uint256 amountInWei = amountInEther * 1 ether;
    require(amountInWei <= address(this).balance, "Insufficient balance.");
    payable(owner()).transfer(amountInWei);
    }

    struct NftType {
        uint256 typeId;
        uint256 percentage;
        string name;
        string description;
    }

    NftType[] private _nftTypes;

    mapping(uint256 => uint256) private _nftRemainingSupply;
    mapping(uint256 => string) private _nftTypeDescriptions;


    function addNftType(uint256 typeId, uint256 percentage, string memory name, string memory typeDescription, uint256 supply) public onlyOwner {
        _nftTypes.push(NftType(typeId, percentage, name, typeDescription));
        _nftRemainingSupply[typeId] = supply;
        _nftTypeDescriptions[typeId] = typeDescription;
    }

    function getNftRemainingSupply(uint256 typeId) public view returns (uint256) {
        return _nftRemainingSupply[typeId];
    }

    function getTotalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function getPriceForQuantity(uint256 quantity) public view returns (uint256) {
        return quantity * pricePerBlindBox;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return string(abi.encodePacked("https://blindbox.com/token/", tokenId));
    }
}