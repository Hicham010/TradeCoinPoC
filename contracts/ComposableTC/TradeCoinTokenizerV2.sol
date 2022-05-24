//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./ITradeCoinTokenizer.sol";

contract TradeCoinTokenizer is ERC721, ITradeCoinTokenizer {
    uint256 public tokenCounter;

    struct TradeCoinCommodity {
        string commodity;
        uint256 amount;
        string unit;
    }

    mapping(uint256 => TradeCoinCommodity) public tradeCoinCommodity;

    constructor() ERC721("TradeCoinTokenizerV2", "TCTV2") {}

    function mintToken(
        string memory _commodity,
        uint256 _amount,
        string memory _unit
    ) external override {
        tradeCoinCommodity[tokenCounter] = TradeCoinCommodity(
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
        tradeCoinCommodity[tokenId].amount += amountIncrease;
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
        tradeCoinCommodity[tokenId].amount -= amountDecrease;
        emit DecreaseCommodity(tokenId, amountDecrease);
    }

    function burnToken(uint256 tokenId) external override {
        require(
            _isApprovedOrOwner(msg.sender, tokenId),
            "caller is not owner nor approved"
        );
        delete tradeCoinCommodity[tokenId];
        _burn(tokenId);
    }

    function getTokenData(uint256 tokenId)
        external
        view
        override
        returns (
            string memory commodity,
            uint256 amount,
            string memory unit
        )
    {
        commodity = tradeCoinCommodity[tokenId].commodity;
        amount = tradeCoinCommodity[tokenId].amount;
        unit = tradeCoinCommodity[tokenId].unit;
    }
}
