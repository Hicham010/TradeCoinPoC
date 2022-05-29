//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "hardhat/console.sol";

contract NutsNFT3 is ERC721, ReentrancyGuard {
    using Strings for uint256;

    uint256 public tokenCounter = 0;

    enum NutState {
        PendingCreation,
        Created,
        PendingProcess,
        Processing,
        PendingTransport,
        Transporting,
        PendingStorage,
        Stored,
        Burned,
        EOL //end of life
    }

    struct Nut {
        bytes nutType;
        uint256 weightGram;
        string[] isoList;
        // bytes32 json_sha3;
        NutState nutState;
    }

    mapping(uint256 => Nut) public nut;
    mapping(uint256 => address) public approvedTransporter;
    mapping(uint256 => address) public approvedProcessor;
    mapping(uint256 => address) public approvedWarehouse;
    mapping(uint256 => address) public transportDestination;
    mapping(uint256 => address) public transportPickUp;

    mapping(uint256 => address) public addressOfNewOwner;
    mapping(uint256 => uint256) public priceForOwnership;
    mapping(uint256 => bool) public payInFiat;

    event NutPending(address indexed creator, uint256 indexed _tokenId);
    event NutCreated(
        address indexed seller,
        address indexed receiver,
        uint256 indexed _tokenId
    );
    event NutDelivered(
        address indexed transporter,
        address indexed receiver,
        uint256 indexed _tokenId
    );
    event NutProcessed(
        address indexed processor,
        address indexed transporter,
        uint256 indexed _tokenId
    );
    event NutStored(
        address indexed warehouse,
        address indexed transporter,
        uint256 indexed _tokenId
    );
    event NutBurned(address indexed nutConsumer, uint256 indexed _tokenId);

    modifier onlyApprovedProcessor(uint256 _tokenId, address _processor) {
        //Also approve NFT holder?
        require(
            approvedProcessor[_tokenId] == _processor,
            "You don't have the right to process"
        );
        require(
            nut[_tokenId].nutState == NutState.Processing ||
                nut[_tokenId].nutState == NutState.PendingProcess,
            "Is not set to processing or pending"
        );
        _;
    }

    modifier onlyApprovedTransporter(uint256 _tokenId, address _transporter) {
        require(
            approvedTransporter[_tokenId] == _transporter,
            "You don't have the right to transport"
        );
        require(
            nut[_tokenId].nutState == NutState.Transporting ||
                nut[_tokenId].nutState == NutState.PendingTransport,
            "Is not set to transporting or pending"
        );
        _;
    }

    modifier onlyApprovedWarehouse(uint256 _tokenId, address _warehouse) {
        require(
            approvedWarehouse[_tokenId] == _warehouse,
            "You don't have the right to store"
        );
        require(
            nut[_tokenId].nutState == NutState.Stored ||
                nut[_tokenId].nutState == NutState.PendingStorage,
            "Is not set to stored or pending"
        );
        _;
    }

    constructor() ERC721("Nuts", "NUT") {}

    function mintNut(uint256 _weightGram, string memory _nutType) public {
        uint256 _tokenId = tokenCounter + 1;
        string[] memory _isoList;
        bytes memory _nutTypeBytes = abi.encodePacked(_nutType);
        // bytes32 _json_sha3 = keccak256(abi.encode(""));
        Nut memory _nut = Nut(
            _nutTypeBytes,
            _weightGram,
            _isoList,
            NutState.PendingCreation
        );

        _mint(msg.sender, _tokenId);
        nut[_tokenId] = _nut;
        tokenCounter = _tokenId;

        emit NutPending(msg.sender, _tokenId);
    }

    function approveNut(uint256 _tokenId, address _receiver) external {
        require(
            msg.sender == ERC721.ownerOf(_tokenId),
            "You are not the owner"
        );

        approve(_receiver, _tokenId);
    }

    function createNut(uint256 _tokenId, address _farmer) external {
        transferFrom(_farmer, msg.sender, _tokenId);
        nut[_tokenId].nutState = NutState.Created;

        emit NutCreated(_farmer, msg.sender, _tokenId);
    }

    function transferOwnership(uint256 _tokenId, address _newOwner) external {
        require(
            nut[_tokenId].nutState != NutState.PendingCreation,
            "This nut is pending for confirmation"
        );
        transferFrom(msg.sender, _newOwner, _tokenId);
    }

    function setPriceForOwnership(
        uint256 _tokenId,
        uint256 priceInWei,
        address _newOwner,
        bool isFiat
    ) external {
        require(
            msg.sender == ERC721.ownerOf(_tokenId),
            "You are not the owner"
        );
        priceForOwnership[_tokenId] = priceInWei;
        addressOfNewOwner[_tokenId] = _newOwner;
        payInFiat[_tokenId] = isFiat;
    }

    function payForOwnership(uint256 _tokenId) external payable nonReentrant {
        bool _payFiat = !payInFiat[_tokenId];
        require(
            addressOfNewOwner[_tokenId] == msg.sender,
            "You don't have the right to pay"
        );
        require(
            priceForOwnership[_tokenId] != 0 || _payFiat,
            "The NFT has no set price"
        );
        require(
            priceForOwnership[_tokenId] <= msg.value,
            "You did not pay enough"
        );

        address addrOwner = ownerOf(_tokenId);

        priceForOwnership[_tokenId] = 0;
        nut[_tokenId].nutState = NutState.Created;

        if (_payFiat) {
            payable(addrOwner).transfer(msg.value);
        }

        _transfer(addrOwner, msg.sender, _tokenId);

        emit NutCreated(addrOwner, msg.sender, _tokenId);
    }

    function pickupNut(uint256 _tokenId, address _sender)
        external
        onlyApprovedTransporter(_tokenId, msg.sender)
    {
        // require(
        //     nut[_tokenId].nutState == NutState.PendingTransport,
        //     "This shipment is not pending for transport"
        // );

        if (
            approvedProcessor[_tokenId] == _sender &&
            transportPickUp[_tokenId] == _sender
        ) {
            emit NutProcessed(_sender, msg.sender, _tokenId);
            // approvedProcessor[_tokenId] = address(0);
        } else if (
            approvedWarehouse[_tokenId] == _sender &&
            transportPickUp[_tokenId] == _sender
        ) {
            emit NutStored(_sender, msg.sender, _tokenId);
            // approvedWarehouse[_tokenId] = address(0);
        }

        nut[_tokenId].nutState = NutState.Transporting;
    }

    function deliveredNut(uint256 _tokenId, address _receiver)
        external
        onlyApprovedTransporter(_tokenId, msg.sender)
    {
        // require(
        //     nut[_tokenId].nutState == NutState.Transporting,
        //     "This shipment is not being transported"
        // );
        if (
            approvedProcessor[_tokenId] == _receiver &&
            transportDestination[_tokenId] == _receiver
        ) {
            nut[_tokenId].nutState = NutState.PendingProcess;
        } else if (
            approvedWarehouse[_tokenId] == _receiver &&
            transportDestination[_tokenId] == _receiver
        ) {
            nut[_tokenId].nutState = NutState.PendingStorage;
        } else {
            revert("This is not an approved receiver or destination");
        }
    }

    function transportForProcessor(
        uint256 _tokenId,
        address _transporter,
        address _receiver
    ) external onlyApprovedProcessor(_tokenId, msg.sender) {
        // require(nut[_tokenId].nutState == NutState.Processing);
        transportPickUp[_tokenId] = msg.sender;
        transportDestination[_tokenId] = _receiver;

        approvedTransporter[_tokenId] = _transporter;
        nut[_tokenId].nutState = NutState.PendingTransport;
    }

    function transportForWarehouse(
        uint256 _tokenId,
        address _transporter,
        address _receiver
    ) external onlyApprovedWarehouse(_tokenId, msg.sender) {
        // require(nut[_tokenId].nutState == NutState.Stored);
        transportPickUp[_tokenId] = msg.sender;
        transportDestination[_tokenId] = _receiver;

        approvedTransporter[_tokenId] = _transporter;
        nut[_tokenId].nutState = NutState.PendingTransport;
    }

    function transportForOwner(
        uint256 _tokenId,
        address _transporter,
        address _receiver
    ) external {
        require(
            msg.sender == ERC721.ownerOf(_tokenId),
            "You are not the owner"
        );
        transportPickUp[_tokenId] = msg.sender;
        transportDestination[_tokenId] = _receiver;

        approvedTransporter[_tokenId] = _transporter;
        nut[_tokenId].nutState = NutState.PendingTransport;
    }

    function processingNut(uint256 _tokenId)
        external
        onlyApprovedProcessor(_tokenId, msg.sender)
    {
        // require(
        //     nut[_tokenId].nutState == NutState.PendingProcess,
        //     "The nut has to be pending for process"
        // );
        nut[_tokenId].nutState = NutState.Processing;

        emit NutDelivered(approvedTransporter[_tokenId], msg.sender, _tokenId);
        // approvedTransporter[_tokenId] = address(0);
    }

    function storringNut(uint256 _tokenId)
        external
        onlyApprovedWarehouse(_tokenId, msg.sender)
    {
        // require(
        //     nut[_tokenId].nutState == NutState.PendingStorage,
        //     "The nut has to be pending for storage"
        // );
        nut[_tokenId].nutState = NutState.Stored;

        emit NutDelivered(approvedTransporter[_tokenId], msg.sender, _tokenId);
        // approvedTransporter[_tokenId] = address(0);
    }

    function burningNut(uint256 _tokenId)
        external
        onlyApprovedWarehouse(_tokenId, msg.sender)
    {
        // require(
        //     nut[_tokenId].nutState == NutState.Stored,
        //     "The nut has to be in stored"
        // );
        nut[_tokenId].nutState == NutState.Burned;

        _burn(_tokenId);

        emit NutBurned(msg.sender, _tokenId);
    }

    function approveTransporter(address _transporter, uint256 _tokenId) public {
        require(
            msg.sender == ERC721.ownerOf(_tokenId),
            "You are not the owner"
        );

        approvedTransporter[_tokenId] = _transporter;
    }

    function approveProcessor(address _processor, uint256 _tokenId) public {
        require(
            msg.sender == ERC721.ownerOf(_tokenId),
            "You are not the owner"
        );

        approvedProcessor[_tokenId] = _processor;
    }

    function approveWarehouse(address _warehouse, uint256 _tokenId) public {
        require(
            msg.sender == ERC721.ownerOf(_tokenId),
            "You are not the owner"
        );

        approvedWarehouse[_tokenId] = _warehouse;
    }

    function batchNuts(uint256 _tokenId1, uint256 _tokenId2) public {
        require(
            msg.sender == ERC721.ownerOf(_tokenId1) &&
                msg.sender == ERC721.ownerOf(_tokenId2),
            "You are not the owner both NFT's"
        );
        require(
            keccak256(abi.encode(nut[_tokenId1].nutType)) ==
                keccak256(abi.encode(nut[_tokenId2].nutType)),
            "The nuts have to be the same kind"
        );
        // require(
        //     nut[_tokenId1].nutState == NutState.Stored &&
        //         nut[_tokenId2].nutState == NutState.Stored,
        //     "The NFT's are not stored"
        // );
        // This will break because a list with the same ISO's but ordered different will produce different hashes
        require(
            keccak256(abi.encode(nut[_tokenId1].isoList)) ==
                keccak256(abi.encode(nut[_tokenId1].isoList)),
            "The nuts have to have the same ISO processes"
        );

        uint256 _weight = nut[_tokenId1].weightGram + nut[_tokenId2].weightGram;
        string memory _nutType = string(nut[_tokenId1].nutType);

        _burn(_tokenId1);
        _burn(_tokenId2);

        mintNut(_weight, _nutType);
        nut[tokenCounter].isoList = nut[_tokenId1].isoList;
        nut[tokenCounter].nutState = NutState.Stored;

        delete nut[_tokenId1];
        delete nut[_tokenId1];
    }

    function decreaseWeight(uint256 _weightGram, uint256 _tokenId)
        public
        onlyApprovedProcessor(_tokenId, msg.sender)
        returns (uint256)
    {
        // require(nut[_tokenId].nutState == NutState.Processing);
        uint256 weight = nut[_tokenId].weightGram;
        require(weight >= _weightGram, "Weight can't be negative");

        console.log(
            "Decreasing weight of %s with amount of %s",
            weight.toString(),
            _weightGram.toString()
        );

        nut[_tokenId].weightGram = weight - _weightGram;

        return nut[_tokenId].weightGram;
    }

    function addISO(string memory _iso, uint256 _tokenId)
        public
        onlyApprovedProcessor(_tokenId, msg.sender)
    {
        // require(nut[_tokenId].nutState == NutState.Processing);
        nut[_tokenId].isoList.push(_iso);
    }

    function getISObyIndex(uint256 _tokenId, uint256 _isoIndex)
        public
        view
        returns (string memory)
    {
        return nut[_tokenId].isoList[_isoIndex];
    }

    function getISOLength(uint256 _tokenId) public view returns (uint256) {
        return nut[_tokenId].isoList.length;
    }

    function getNutState(uint256 _tokenId) public view returns (NutState) {
        return nut[_tokenId].nutState;
    }

    function getNutType(uint256 _tokenId) public view returns (string memory) {
        return string(nut[_tokenId].nutType);
    }

    function getNutWeight(uint256 _tokenId) public view returns (uint256) {
        return nut[_tokenId].weightGram;
    }
}
