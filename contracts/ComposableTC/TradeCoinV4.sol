// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./TradeCoinTokenizerV2.sol";
import "./RoleControl.sol";
// import "hardhat/console.sol";

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract TradeCoinV4 is ERC721, RoleControl, ReentrancyGuard, IERC721Receiver {
    TradeCoinTokenizerv2 public tradeCoinTokenizerv2;
    uint256 public tokenCounter;

    // structure of the metadata
    struct TradeCoinCommodity {
        uint256 amount;
        State state;
        bytes32 hashOfProperties;
        address currentHandler;
    }

    struct CommoditySaleQueue {
        address seller;
        address owner;
        address handler;
        uint256 priceInWei;
        bool isPayed;
    }

    // Enum of state of productNFT
    enum State {
        NonExistent,
        Created,
        PendingProcess,
        Processing,
        PendingTransport,
        Transporting,
        PendingStorage,
        Stored,
        EOL //end of life
    }

    // Definition of Events
    event MintCommodity(
        uint256 indexed tokenId,
        address indexed tokenizer,
        uint256 tokenIdTCT,
        string commodityName,
        uint256 amount,
        string unit
        // bytes32 docHash,
        // string docType,
        // bytes32 rootHash
    );

    event CommodityTransformation(
        uint256 indexed tokenId,
        address indexed transformer,
        string transformation
        // bytes32 docHash,
        // string docType,
        // bytes32 rootHash
    );

    event CommodityTransformation(
        uint256 indexed tokenId,
        address indexed transformer,
        string transformation,
        uint256 amountDecrease
        // bytes32 docHash,
        // string docType,
        // bytes32 rootHash
    );

    event SplitCommodity(
        uint256 indexed tokenId,
        address indexed splitter,
        uint256[] newTokenIds
        // bytes32 docHash,
        // string docType,
        // bytes32 rootHash
    );

    event BatchCommodities(
        address indexed batcher,
        uint256[] tokenIds
        // bytes32 docHash,
        // string docType,
        // bytes32 rootHash
    );

    event InitiateCommercialTx(
        uint256 indexed tokenIdTCT,
        address indexed seller,
        address indexed buyer,
        uint256 priceInWei,
        bool payInFiat
    );

    event PayForCommercialTx(
        uint256 indexed tokenIdTCT,
        address indexed payer,
        uint256 priceInWei
        // bytes32 dochash,
        // string docType,
        // bytes32 rootHash
    );

    event FinishCommercialTx(
        uint256 indexed tokenId,
        address indexed seller,
        address indexed functionCaller
        // bytes32 dochash,
        // string docType,
        // bytes32 rootHash
    );

    event BurnCommodity(
        uint256 indexed tokenId,
        address indexed burner
        // bytes32 docHash,
        // string docType,
        // bytes32 rootHash
    );

    event ChangeStateAndHandler(
        uint256 indexed tokenId,
        address indexed functionCaller,
        address newCurrentHandler,
        State newState
        // bytes32 docHash,
        // string docType,
        // bytes32 rootHash
    );

    event QualityCheckCommodity(
        uint256 indexed tokenId,
        address indexed checker,
        string data
        // bytes32 docHash,
        // string docType,
        // bytes32 rootHash
    );

    event LocationOfCommodity(
        uint256 indexed tokenId,
        address indexed locationSignaler,
        uint256 latitude,
        uint256 longitude,
        uint256 radius
        // bytes32 docHash,
        // string docType,
        // bytes32 rootHash
    );

    event AddInformation(
        uint256 indexed tokenId,
        address indexed functionCaller,
        string data
        // bytes32 docHash,
        // string docType,
        // bytes32 rootHash
    );

    event CommodityOutOfChain(
        uint256 indexed tokenId,
        address indexed funCaller
    );

    // Mapping for the metadata of the tradecoin
    mapping(uint256 => TradeCoinCommodity) public tradeCoinCommodity;
    mapping(uint256 => CommoditySaleQueue) public commoditySale;

    constructor(string memory _name, string memory _symbol)
        ERC721(_name, _symbol)
        RoleControl(msg.sender)
    {}

    function onERC721Received(
        address tokenizer,
        address,
        uint256 tokenIdOfTCT,
        bytes calldata _data
    ) external virtual override returns (bytes4) {
        require(
            address(tradeCoinTokenizerv2) == msg.sender,
            "Not the tokenizer contract"
        );

        (address owner, address handler, uint256 priceInWei) = abi.decode(
            _data,
            (address, address, uint256)
        );

        commoditySale[tokenIdOfTCT] = CommoditySaleQueue(
            tokenizer,
            owner,
            handler,
            priceInWei,
            priceInWei == 0
        );

        emit InitiateCommercialTx(
            tokenIdOfTCT,
            tokenizer,
            owner,
            priceInWei,
            priceInWei == 0
        );

        return this.onERC721Received.selector;
    }

    function paymentOfToken(uint256 tokenIdOfTCT) external payable {
        require(
            commoditySale[tokenIdOfTCT].priceInWei == msg.value,
            "Not enough Ether"
        );
        commoditySale[tokenIdOfTCT].isPayed = true;
        emit PayForCommercialTx(
            tokenIdOfTCT,
            msg.sender,
            commoditySale[tokenIdOfTCT].priceInWei
        );
    }

    function mintToken(uint256 tokenIdOfTCT) external {
        require(commoditySale[tokenIdOfTCT].isPayed, "Not payed for yet");
        require(
            commoditySale[tokenIdOfTCT].handler == msg.sender,
            "Not a handler"
        );

        if (!(commoditySale[tokenIdOfTCT].priceInWei == 0)) {
            payable(commoditySale[tokenIdOfTCT].seller).transfer(
                commoditySale[tokenIdOfTCT].priceInWei
            );
        }
        _safeMint(commoditySale[tokenIdOfTCT].owner, tokenCounter);

        (bytes32 hashOfProperties, uint256 amount) = emitTokenData(
            tokenCounter,
            tokenIdOfTCT
        );

        tradeCoinCommodity[tokenCounter] = TradeCoinCommodity(
            amount,
            State.Created,
            hashOfProperties,
            msg.sender
        );

        tradeCoinTokenizerv2.burn(tokenIdOfTCT);

        emit FinishCommercialTx(
            tokenCounter,
            commoditySale[tokenIdOfTCT].seller,
            msg.sender
        );

        delete commoditySale[tokenIdOfTCT];
        tokenCounter += 1;
    }

    function emitTokenData(uint256 _tokenId, uint256 tokenIdOfTCT)
        internal
        returns (bytes32, uint256)
    {
        bytes memory data = tradeCoinTokenizerv2.getTokenData(tokenIdOfTCT);

        (string memory commodity, uint256 amount, string memory unit) = abi
            .decode(data, (string, uint256, string));

        emit MintCommodity(
            _tokenId,
            msg.sender,
            tokenIdOfTCT,
            commodity,
            amount,
            unit
        );

        emit CommodityTransformation(_tokenId, msg.sender, "raw");

        return (keccak256(abi.encodePacked(commodity, unit, "raw")), amount);
    }

    function addTransformation(uint256 _tokenId, string memory transformation)
        external
    {
        tradeCoinCommodity[_tokenId].hashOfProperties = keccak256(
            abi.encodePacked(
                tradeCoinCommodity[_tokenId].hashOfProperties,
                transformation
            )
        );

        emit CommodityTransformation(_tokenId, msg.sender, transformation);
    }

    function addTransformation(
        uint256 _tokenId,
        string memory transformation,
        uint256 amountDecrease
    ) external {
        tradeCoinCommodity[_tokenId].amount -= amountDecrease;

        tradeCoinCommodity[_tokenId].hashOfProperties = keccak256(
            abi.encodePacked(
                tradeCoinCommodity[_tokenId].hashOfProperties,
                transformation
            )
        );

        emit CommodityTransformation(
            _tokenId,
            msg.sender,
            transformation,
            amountDecrease
        );
    }

    function changeCurrentHandlerAndState(
        uint256 _tokenId,
        address newHandler,
        State newCommodityState
    ) external {
        tradeCoinCommodity[_tokenId].currentHandler = newHandler;
        tradeCoinCommodity[_tokenId].state = newCommodityState;

        emit ChangeStateAndHandler(
            _tokenId,
            msg.sender,
            newHandler,
            newCommodityState
        );
    }

    function addInformationToCommodity(uint256 _tokenId, string memory data)
        external
    {
        emit AddInformation(_tokenId, msg.sender, data);
    }

    function checkQualityOfCommodity(uint256 _tokenId, string memory data)
        external
    {
        emit QualityCheckCommodity(_tokenId, msg.sender, data);
    }

    function confirmCommodityLocation(
        uint256 _tokenId,
        uint256 latitude,
        uint256 longitude,
        uint256 radius
    ) external {
        emit LocationOfCommodity(
            _tokenId,
            msg.sender,
            latitude,
            longitude,
            radius
        );
    }

    function batchCommodities(uint256[] memory _tokenIds) external {}

    function splitCommodity(uint256 _tokenIds, uint256 partitions) external {}

    // Function must be overridden as ERC721 and AccesControl are conflicting
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
