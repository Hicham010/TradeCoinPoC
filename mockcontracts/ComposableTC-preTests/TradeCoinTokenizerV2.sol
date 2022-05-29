//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./ITradeCoinTokenizer.sol";

contract TradeCoinTokenizerV2 is ERC721, ITradeCoinTokenizer {
    uint256 public tokenCounter;

    struct TradeCoinToken {
        string commodity;
        uint256 amount;
        string unit;
    }

    mapping(uint256 => TradeCoinToken) public tradeCoinToken;

    constructor() ERC721("TradeCoinTokenizerV2", "TCTV2") {}

    function mintToken(
        string memory _commodity,
        uint256 _amount,
        string memory _unit
    ) external override {
        tradeCoinToken[tokenCounter] = TradeCoinToken(
            _commodity,
            _amount,
            _unit
        );
        _mint(msg.sender, tokenCounter);

        tokenCounter += 1;
    }

    function increaseAmount(uint256 tokenId, uint256 amountIncrease)
        external
        override
    {
        require(
            _isApprovedOrOwner(msg.sender, tokenId),
            "Caller is not owner nor approved"
        );
        tradeCoinToken[tokenId].amount += amountIncrease;
        emit IncreaseCommodity(tokenId, amountIncrease);
    }

    function decreaseAmount(uint256 tokenId, uint256 amountDecrease)
        external
        override
    {
        require(
            _isApprovedOrOwner(msg.sender, tokenId),
            "Caller is not owner nor approved"
        );
        tradeCoinToken[tokenId].amount -= amountDecrease;
        emit DecreaseCommodity(tokenId, amountDecrease);
    }

    function burnToken(uint256 tokenId) external override {
        require(
            _isApprovedOrOwner(msg.sender, tokenId),
            "caller is not owner nor approved"
        );
        delete tradeCoinToken[tokenId];
        _burn(tokenId);
    }
}