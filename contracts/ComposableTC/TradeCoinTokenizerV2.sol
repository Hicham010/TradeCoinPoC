//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./TradeCoinV4.sol";

import "hardhat/console.sol";

contract TradeCoinTokenizerv2 is ERC721 {
    uint256 public tokenCounter;
    TradeCoinV4 public tradeCoinV4;

    struct TradeCoinCommodity {
        string commodity;
        uint256 amount;
        string unit;
    }

    event InitializeSaleInCrypto(
        uint256 indexed tokenId,
        address indexed tokenizer,
        address indexed owner,
        uint256 priceInWei
    );
    event InitializeSaleInFiat(
        uint256 indexed tokenId,
        address indexed tokenizer,
        address indexed owner
    );
    event IncreaseCommodity(uint256 indexed tokenId, uint256 amountIncrease);
    event DecreaseCommodity(uint256 indexed tokenId, uint256 amountDecrease);

    mapping(uint256 => TradeCoinCommodity) public tradeCoinCommodity;

    constructor() ERC721("TradeCoinTokenizerV2", "TCTv2") {}

    function mintCommodity(
        string memory _commodity,
        uint256 _amount,
        string memory _unit
    ) external {
        tradeCoinCommodity[tokenCounter] = TradeCoinCommodity(
            _commodity,
            _amount,
            _unit
        );
        _safeMint(msg.sender, tokenCounter);

        tokenCounter += 1;
    }

    function initializeCommoditySaleInCrypto(
        uint256 tokenId,
        address owner,
        address handler,
        uint256 priceInWei
    ) external {
        bytes memory data = abi.encode(owner, handler, priceInWei);
        safeTransferFrom(msg.sender, address(tradeCoinV4), tokenId, data);
        emit InitializeSaleInCrypto(tokenId, msg.sender, owner, priceInWei);
    }

    function initializeCommoditySaleInFiat(
        uint256 tokenId,
        address owner,
        address handler
    ) external {
        bytes memory data = abi.encode(owner, handler, 0);
        safeTransferFrom(msg.sender, address(tradeCoinV4), tokenId, data);
        emit InitializeSaleInFiat(tokenId, msg.sender, owner);
    }

    function increaseAmount(uint256 tokenId, uint256 amountIncrease) external {
        require(ownerOf(tokenId) == msg.sender, "Not the owner");
        tradeCoinCommodity[tokenId].amount += amountIncrease;
        emit IncreaseCommodity(tokenId, amountIncrease);
    }

    function decreaseAmount(uint256 tokenId, uint256 amountDecrease) external {
        require(ownerOf(tokenId) == msg.sender, "Not the owner");
        tradeCoinCommodity[tokenId].amount -= amountDecrease;
        emit DecreaseCommodity(tokenId, amountDecrease);
    }

    function burn(uint256 tokenId) external {
        require(
            _isApprovedOrOwner(msg.sender, tokenId),
            "ERC721Burnable: caller is not owner nor approved"
        );
        delete tradeCoinCommodity[tokenId];
        _burn(tokenId);
    }

    function getTokenData(uint256 tokenId)
        external
        view
        returns (bytes memory data)
    {
        data = abi.encode(
            tradeCoinCommodity[tokenId].commodity,
            tradeCoinCommodity[tokenId].amount,
            tradeCoinCommodity[tokenId].unit
        );
    }
}
