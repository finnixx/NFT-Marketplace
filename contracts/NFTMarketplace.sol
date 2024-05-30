// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "hardhat/console.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract NFTMarketplace is ERC721URIStorage{
  using Counters for Counters.Counter;

  Counters.Counter private _tokenIds;
  Counters.Counter private _itemsSold;
  AggregatorV3Interface internal priceFeed;
  address payable owner;

  mapping(uint256 => MarketItem) private idMarketItem;

  struct MarketItem {
      uint256 tokenId;
      address payable seller;
      address payable owner;
      uint256 price ;
      bool isSold;
  }
  
  event idMarketItemCreated (
    uint256 indexed tokenId,
    address seller,
    address owner,
    uint256 price,
    bool isSold
  );

  modifier onlyOwner(){
    require(msg.sender == owner);
    _;
  };

  constructor() ERC721 ("NFT-Token", "NFT") {
   owner = payable(msg.sender);
  };

  function getChainlinkDataFeedLatestAnswer() public view returns (int) {
    	(,int price,,,) = priceFeed.latestRoundData();
    	return price;
	}

  function createToken(string memory tokenURI, uint256 price) public payable returns(uint256){
    
    _tokenIds.increment();

    uint256 newTokenId = _tokenIds.current();

    _mint(msg.sender,newTokenId);
    _setTokenURI(newTokenId,tokenURI);

    createMarketItem(newTokenId,price);
    return newTokenId;

  }

  function createMarketItem(uint256 tokenId, uint256 price) private {
    require ( price>0, "Price must be atleast One");
    require (msg.value == price/10 ,"Price must be equal to Listing Price");
   
    
    idMarketItem[tokenId] = MarketItem(
        tokenId,
        payable(msg.sender),
        payable(address(this)),
        price,
        false
    );

    _transfer(msg.sender,address(this),tokenId);

    emit idMarketItemCreated(tokenId,msg.sender,address(this),price,false);


  }

  function createMarketSale(uint256 tokenId) public payable {
    uint256 price = idMarketItem[tokenId].price;
    uint256 ethUsd = 1/uint256(getChainlinkDataFeedLatestAnswer());
    uint256 amountEth = price *ethUsd;



    require(msg.value == amountEth, "Please submit the asking price in order");

    idMarketItem[tokenId].owner = payable(msg.sender);
    idMarketItem[tokenId].isSold = true;

    _itemsSold.increment();

    uint256 listingPrice = amountEth/10;

    bool success1 = payable(address(this)).send(listingPrice);
    require(success1, "Transfer failed.");

    bool success2 = payable(idMarketItem[tokenId].seller).send(msg.value);
    require(success2, "Transfer failed");
      // AFTER TRANSFER OF FUNDS THE TOKEN IS TRANSFERED
    _transfer(address(this),msg.sender,tokenId);


  }

  function fetchMarketItem () public view returns (MarketItem[] memory) {
      uint256 itemCount = _tokenIds.current();
      uint256 unSoldItemCount = _tokenIds.current()-_itemsSold.current();
      uint256 currentIndex = 0;

      MarketItem [] memory items = new MarketItem[](unSoldItemCount);

      for(uint256 i = 0; i<itemCount ; i++){
        if(idMarketItem[i+1].owner= address(this)){
            uint256 currentId = i+1;
            MarketItem storage currentItem = idMarketItem[currentId];
            items[currentIndex] = currentItem;
            currentIndex +=1;

        }
      }
      return items;
  }

  
}
