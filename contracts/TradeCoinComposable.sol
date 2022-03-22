// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract TradeCoinTokenizer is ERC721 {
    using Counters for Counters.Counter;

    struct CommodityStruct {
        CommodityState state;
        string commodityType;
        uint256 weightInGram;
        string[] isoList;
        address pickupAddress;
        address destinationAddress;
    }

    enum CommodityState {
        PendingConfirmation,
        Confirmed,
        PendingProcess,
        Processing,
        PendingTransport,
        Transporting,
        PendingStorage,
        Stored,
        EOL
    }

    Counters.Counter private _tokenIdCounter;

    constructor() ERC721("TradeCoinTokenizer", "TCT") {}

    mapping(uint256 => CommodityStruct) public Commodity;

    function safeMint(
        address to,
        uint256 weightInGram,
        string memory commodityType
    ) public {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);

        string[] memory emptyList;
        uint256 id = tokenId;

        CommodityStruct memory _commodity = CommodityStruct(
            CommodityState.PendingConfirmation,
            commodityType,
            weightInGram,
            emptyList,
            address(0),
            address(0)
        );

        Commodity[id] = _commodity;
    }

    function addProcess(uint256 _id, string memory _process) external {
        require(msg.sender == ownerOf(_id), "You are not the owner");
        Commodity[_id].isoList.push(_process);
    }

    function decreaseWeight(uint256 _id, uint256 decreaseAmount) external {
        require(msg.sender == ownerOf(_id), "You are not the owner");
        Commodity[_id].weightInGram -= decreaseAmount;
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

    function dataOf(uint256 _id) public view returns (CommodityStruct memory) {
        CommodityStruct memory _tradeCoinStruct = Commodity[_id];
        require(
            _tradeCoinStruct.pickupAddress != address(0),
            "Token not received"
        );
        return _tradeCoinStruct;
    }

    // modifier onlySetupContract(msg.sender) {
    //     require(msg.sender == SetupAddr)
    // }
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

    mapping(uint256 => bool) blockTokenId;

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
        tradeCoinRightsAddr = _tradeCoinRightsAddr;
        tradeCoinDataAddr = _tradeCoinDataAddr;
        tradeCoinTokenizer = TradeCoinTokenizer(_tradeCoinTokenizerAddr);
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

    function addProcess(uint256 _id, string memory _process) external {
        require(
            tradeCoinDataAddr == msg.sender,
            "You are not the owner of this data token"
        );

        tradeCoinTokenizer.addProcess(_id, _process);
    }

    function decreaseWeight(uint256 _id, uint256 decreaseAmount) external {
        require(
            tradeCoinDataAddr == msg.sender,
            "You are not the owner of this data token"
        );

        tradeCoinTokenizer.decreaseWeight(_id, decreaseAmount);
    }

    function blockIdOfToken(uint256 _id, bool _block) external {
        require(
            tradeCoinRightsAddr == msg.sender,
            "You don't own the rights token"
        );
        blockTokenId[_id] = _block;
    }

    modifier isBlocked(uint256 _id) {
        require(
            !blockTokenId[_id],
            "The owner has blocked wrights to this token"
        );
        _;
    }
}

contract TradeCoinRights is ERC721 {
    using Counters for Counters.Counter;

    TradeCoinSetup tradeCoinSetup;
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
        tradeCoinSetup = TradeCoinSetup(_tradeCoinSetupAddr);
        tradeCoinSetupAddr = _tradeCoinSetupAddr;
    }
}

contract TradeCoinData is ERC721 {
    using Counters for Counters.Counter;

    TradeCoinSetup tradeCoinSetup;
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
        tradeCoinSetup = TradeCoinSetup(_tradeCoinSetupAddr);
        tradeCoinSetupAddr = _tradeCoinSetupAddr;
    }

    function addProcess(uint256 _id, string memory _process) external {
        require(
            ownerOf(_id) == msg.sender,
            "You are not the owner of this data token"
        );

        tradeCoinSetup.addProcess(_id, _process);
    }

    function decreaseWeight(uint256 _id, uint256 decreaseAmount) external {
        require(
            ownerOf(_id) == msg.sender,
            "You are not the owner of this data token"
        );

        tradeCoinSetup.decreaseWeight(_id, decreaseAmount);
    }
}

contract TradeCoinSale is IERC721Receiver {
    TradeCoinTokenizer tradeCoinTokenizer;
    address public tradeCoinTokenizerAddr;

    struct TradeCoinSaleData {
        address seller;
        address receiver;
        uint256 priceInWei;
        bool fiat;
        bool isPayed;
    }

    constructor(address _tradeCoinTokenizerAddr) {
        tradeCoinTokenizerAddr = _tradeCoinTokenizerAddr;
        tradeCoinTokenizer = TradeCoinTokenizer(_tradeCoinTokenizerAddr);
    }

    mapping(uint256 => TradeCoinSaleData) private tradeCoinSaleData;
    mapping(uint256 => bool) withdrawnPayment;
    mapping(uint256 => bool) withdrawnToken;

    event SetupSale(
        address indexed seller,
        address indexed receiver,
        uint256 indexed tokenId,
        uint256 priceInWei
    );
    event SetupSale(
        address indexed seller,
        address indexed receiver,
        uint256 indexed tokenId,
        bool fiat
    );
    event DepositPayment(address indexed depositer, uint256 indexed tokenId);
    event WithdrawPayment(address indexed withdrawer, uint256 indexed tokenId);
    event WithdrawToken(address indexed withdrawer, uint256 indexed tokenId);

    function onERC721Received(
        address _seller,
        address,
        uint256 _id,
        bytes memory _data
    ) public virtual override returns (bytes4) {
        require(
            tradeCoinTokenizerAddr == msg.sender,
            "This is not the address of the TradeCoin Tokenizer"
        );

        (uint256 _priceInWei, address _receiver, bool _fiat) = abi.decode(
            _data,
            (uint256, address, bool)
        );
        // bool _isPayed = _fiat ? true : false;
        if (_fiat) {
            emit SetupSale(_seller, _receiver, _id, true);
            tradeCoinSaleData[_id] = TradeCoinSaleData(
                _seller,
                _receiver,
                0,
                true,
                true
            );
            withdrawnPayment[_id] = true;
        } else {
            emit SetupSale(_seller, _receiver, _id, _priceInWei);
            tradeCoinSaleData[_id] = TradeCoinSaleData(
                _seller,
                _receiver,
                _priceInWei,
                false,
                false
            );
            withdrawnPayment[_id] = false;
        }

        withdrawnToken[_id] = false;

        return this.onERC721Received.selector;
    }

    function payForToken(uint256 _id) external payable {
        TradeCoinSaleData memory _tradeCoinSaleData = dataOf(_id);
        require(!_tradeCoinSaleData.isPayed, "This token is already payed for");
        require(
            (_tradeCoinSaleData.priceInWei) == msg.value,
            "This is not the right amount"
        );

        emit DepositPayment(msg.sender, _id);
    }

    function withdrawPayment(uint256 _id) external {
        TradeCoinSaleData memory _tradeCoinSaleData = dataOf(_id);
        require(
            !withdrawnPayment[_id],
            "The payment has already been withdrawn"
        );
        require(!_tradeCoinSaleData.fiat, "This token has been payed in fiat");
        require(_tradeCoinSaleData.isPayed, "This token is not payed for");
        _tradeCoinSaleData.isPayed = false;
        withdrawnPayment[_id] = true;
        payable(_tradeCoinSaleData.seller).transfer(
            _tradeCoinSaleData.priceInWei
        );

        emit WithdrawPayment(msg.sender, _id);
    }

    function withdrawToken(uint256 _id) external {
        TradeCoinSaleData memory _tradeCoinSaleData = dataOf(_id);
        require(!withdrawnToken[_id], "The token has already been withdrawn");
        require(_tradeCoinSaleData.isPayed, "This token is not payed for");
        withdrawnToken[_id] = true;

        tradeCoinTokenizer.safeTransferFrom(
            address(this),
            _tradeCoinSaleData.receiver,
            _id
        );
        emit WithdrawToken(msg.sender, _id);
    }

    function dataOf(uint256 _id)
        public
        view
        returns (TradeCoinSaleData memory)
    {
        TradeCoinSaleData memory _tradeCoinSaleData = tradeCoinSaleData[_id];
        require(_tradeCoinSaleData.seller != address(0), "Token not received");
        return _tradeCoinSaleData;
    }

    // function setTradeCoinSetupAddr(address _tradeCoinTokenizerAddr) public {
    //     tradeCoinTokenizerAddr = _tradeCoinTokenizerAddr;
    //     tradeCoinTokenizer = TradeCoinTokenizer(_tradeCoinTokenizerAddr);
    // }
}
