// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract TradeCoinTokenizer is ERC721 {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    constructor() ERC721("TradeCoinTokenizer", "TCT") {}

    function safeMint(address to) public {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
    }

    function transfer(
        address _to,
        uint256 id,
        uint256 priceInEth,
        address warehouse,
        address financer,
        bool fiat
    ) public {
        bytes memory _data = abi.encode(priceInEth, warehouse, financer, fiat);
        safeTransferFrom(msg.sender, _to, id, _data);
    }
}

contract TradeCoinSetup is IERC721Receiver {
    TradeCoinTokenizer tradeCoinTokenizer;
    TradeCoinRights tradeCoinRights;
    TradeCoinData tradeCoinData;

    address public tradeCoinTokenizerAddr;
    address public tradeCoinRightsAddr;
    address public tradeCoinDataAddr;

    constructor() {}

    struct TradeCoindDR {
        uint256 price;
        address farmer;
        address warehouse;
        address financer;
        bool fiat;
    }

    mapping(uint256 => TradeCoindDR) tradecoindr;
    mapping(uint256 => bool) payedEth;

    event saleInitialized(
        uint256 indexed _id,
        address indexed warehouse,
        address indexed financer,
        address farmer,
        bool fiat,
        uint256 price
    );

    event saleCompleted(uint256 indexed _id);
    event saleReversed(uint256 indexed _id);

    function onERC721Received(
        address _farmer,
        address,
        uint256 _idOfTokenizer,
        bytes memory _data
    ) public virtual override returns (bytes4) {
        require(
            tradeCoinTokenizerAddr == msg.sender,
            "This is not the address of the TradeCoin Tokenizer"
        );

        (
            uint256 _price,
            address _warehouse,
            address _financer,
            bool _fiat
        ) = abi.decode(_data, (uint256, address, address, bool));
        TradeCoindDR memory _tradecoindr = TradeCoindDR(
            _price,
            _farmer,
            _warehouse,
            _financer,
            _fiat
        );
        tradecoindr[_idOfTokenizer] = _tradecoindr;
        emit saleInitialized(
            _idOfTokenizer,
            _warehouse,
            _financer,
            _financer,
            _fiat,
            _price
        );

        return this.onERC721Received.selector;
    }

    function setTradeCoinTokenizerAddr(
        address _tradeCoinTokenizerAddr,
        address _tradeCoinRightsAddr,
        address _tradeCoinDataAddr
    ) public {
        tradeCoinTokenizerAddr = _tradeCoinTokenizerAddr;
        tradeCoinRights = TradeCoinRights(_tradeCoinRightsAddr);
        tradeCoinData = TradeCoinData(_tradeCoinDataAddr);
    }

    function payForToken(uint256 _id) public payable {
        uint256 _price = tradecoindr[_id].price;
        require(msg.value == _price);
        payedEth[_id] = true;
    }

    function completeSale(uint256 _id) public {
        address _farmer = tradecoindr[_id].farmer;
        address _financer = tradecoindr[_id].financer;
        address _warehouse = tradecoindr[_id].warehouse;

        require(
            msg.sender == _warehouse,
            "You are not part of this transaction"
        );

        bool _fiat = tradecoindr[_id].fiat;
        if (!_fiat) {
            //TODO: discuss
            require(payedEth[_id], "You did not pay yet");
            uint256 _price = tradecoindr[_id].price;
            payable(_farmer).transfer(_price);
        }

        tradeCoinRights.safeMint(_financer);
        tradeCoinData.safeMint(_warehouse);
        emit saleCompleted(_id);
    }

    function reverseSale(uint256 _id) public {
        address _farmer = tradecoindr[_id].farmer;
        address _financer = tradecoindr[_id].financer;
        address _warehouse = tradecoindr[_id].warehouse;

        require(
            msg.sender == _farmer ||
                msg.sender == _financer ||
                msg.sender == _warehouse,
            "You are not part of this transaction"
        );

        tradeCoinTokenizer.safeTransferFrom(address(this), _farmer, _id);

        bool _fiat = tradecoindr[_id].fiat;
        if (!_fiat) {
            //TODO: discuss
            require(payedEth[_id], "You did not pay yet");
            uint256 _price = tradecoindr[_id].price;
            payable(_financer).transfer(_price);
        }

        delete tradecoindr[_id];
        emit saleReversed(_id);
    }
}

contract TradeCoinRights is ERC721 {
    using Counters for Counters.Counter;

    address public tradeCoinSetupAddr;
    Counters.Counter private _tokenIdCounter;

    constructor() ERC721("TradeCoinRights", "TCR") {}

    function safeMint(address to) public {
        require(
            tradeCoinSetupAddr == msg.sender,
            "This is not the address of the TradeCoin Setup"
        );

        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
    }

    function transfer(address _to, uint256 id) public {
        safeTransferFrom(msg.sender, _to, id);
    }

    function setTradeCoinSetupAddr(address _tradeCoinSetupAddr) public {
        tradeCoinSetupAddr = _tradeCoinSetupAddr;
    }
}

contract TradeCoinData is ERC721 {
    using Counters for Counters.Counter;

    address public tradeCoinSetupAddr;
    Counters.Counter private _tokenIdCounter;

    constructor() ERC721("TradeCoinData", "TCD") {}

    function safeMint(address to) public {
        require(
            tradeCoinSetupAddr == msg.sender,
            "This is not the address of the TradeCoin Setup"
        );

        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
    }

    function transfer(address _to, uint256 id) public {
        safeTransferFrom(msg.sender, _to, id);
    }

    function setTradeCoinSetupAddr(address _tradeCoinSetupAddr) public {
        tradeCoinSetupAddr = _tradeCoinSetupAddr;
    }
}
