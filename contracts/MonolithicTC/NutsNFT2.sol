//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
// Not needed for solidity 0.8.x
// import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
// import "@openzeppelin/contracts/utils/Counters.sol";

import "hardhat/console.sol";

contract NutsNFT2 is ERC721 {
    using Strings for uint256;

    uint256 public tokenCounter = 0;

    enum nutState {
        PendingCreation,
        Created,
        PendingProcess,
        Processing,
        PendingTransport,
        Transporting,
        PendingStorage,
        Stored,
        Burned,
        EOL
    }

    struct Nut {
        string nut_type;
        // uint total_bags;
        // uint[] weights;
        uint256 weight_gram;
        string[] ISO_list;
        // bytes32 json_sha3;
        nutState nut_state;
    }

    mapping(uint256 => Nut) public nut;
    mapping(uint256 => address) public approvedTransporter;
    mapping(uint256 => address) public approvedProcessor;
    mapping(uint256 => address) public approvedWarehouse;
    mapping(uint256 => address) public transportDestination;
    mapping(uint256 => address) public transportPickUp;

    event NutPending(address indexed creator, uint256 indexed _tokenId);
    event NutCreated(
        address indexed seller,
        address indexed receiver,
        uint256 indexed _tokenId
    );
    event NutDelevered(
        address indexed transporter,
        address indexed receiver,
        uint256 indexed _tokenId
    );
    event NutProcessed(
        address indexed processor,
        address indexed receiver,
        uint256 indexed _tokenId
    );
    event NutStored(
        address indexed warehouse,
        address indexed receiver,
        uint256 indexed _tokenId
    );
    event NutBurned(address indexed nutConsumer, uint256 indexed _tokenId);

    modifier onlyApprovedProcessor(uint256 _tokenId, address _processor) {
        //Also approve NFT holder?
        require(
            approvedTransporter[_tokenId] == _processor,
            "You don't have the right to "
        );
        // require(nut[_tokenId].nut_state == nutState.Transporting, "Is not set to transporting");
        _;
    }

    modifier onlyApprovedTransporter(uint256 _tokenId, address _transporter) {
        require(
            approvedTransporter[_tokenId] == _transporter,
            "You don't have the right to add processes"
        );
        // require(nut[_tokenId].nut_state == nutState.Processing, "Is not set to transporting");
        _;
    }

    modifier onlyApprovedWarehouse(uint256 _tokenId, address _warehouse) {
        require(
            approvedWarehouse[_tokenId] == _warehouse,
            "You don't have the right to store"
        );
        // require(nut[_tokenId].nut_state == nutState.Stored, "Is not set to stored");
        _;
    }

    constructor() ERC721("Nuts", "NUT") {}

    function mintNut(uint256 _weight_gram, string memory _nut_type) external {
        uint256 _tokenId = tokenCounter + 1;
        string[] memory _ISO_list;
        // bytes32 _json_sha3 = keccak256(abi.encode(""));
        Nut memory _nut = Nut(
            _nut_type,
            _weight_gram,
            _ISO_list,
            nutState.PendingCreation
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

    function createNut(uint256 _tokenId, address _buyer) external {
        transferFrom(_buyer, msg.sender, _tokenId);
        nut[_tokenId].nut_state = nutState.Created;

        emit NutCreated(_buyer, msg.sender, _tokenId);
    }

    function transferOwnership(uint256 _tokenId, address _newOwner) external {
        require(
            nut[_tokenId].nut_state != nutState.PendingCreation,
            "This nut is pending for confirmation"
        );
        transferFrom(_newOwner, msg.sender, _tokenId);
    }

    function pickupNut(uint256 _tokenId, address _sender)
        external
        onlyApprovedTransporter(_tokenId, msg.sender)
    {
        require(nut[_tokenId].nut_state == nutState.PendingTransport);

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

        nut[_tokenId].nut_state = nutState.Transporting;
    }

    function deleveredNut(uint256 _tokenId, address _receiver)
        external
        onlyApprovedTransporter(_tokenId, msg.sender)
    {
        if (
            approvedProcessor[_tokenId] == _receiver &&
            transportDestination[_tokenId] == _receiver
        ) {
            nut[_tokenId].nut_state = nutState.PendingProcess;
        } else if (
            approvedWarehouse[_tokenId] == _receiver &&
            transportDestination[_tokenId] == _receiver
        ) {
            nut[_tokenId].nut_state = nutState.PendingStorage;
        } else {
            revert("This is not an approved receiver or destination");
        }
    }

    function transportForProcessor(
        uint256 _tokenId,
        address _transporter,
        address _receiver
    ) external onlyApprovedProcessor(_tokenId, msg.sender) {
        require(nut[_tokenId].nut_state == nutState.Processing);
        transportPickUp[_tokenId] = msg.sender;
        transportDestination[_tokenId] = _receiver;

        approvedTransporter[_tokenId] = _transporter;
        nut[_tokenId].nut_state = nutState.PendingTransport;
    }

    function transportForWarehouse(
        uint256 _tokenId,
        address _transporter,
        address _receiver
    ) external onlyApprovedWarehouse(_tokenId, msg.sender) {
        require(nut[_tokenId].nut_state == nutState.Stored);
        transportPickUp[_tokenId] = msg.sender;
        transportDestination[_tokenId] = _receiver;

        approvedTransporter[_tokenId] = _transporter;
        nut[_tokenId].nut_state = nutState.PendingTransport;
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
        nut[_tokenId].nut_state = nutState.PendingTransport;
    }

    function processingNut(uint256 _tokenId)
        external
        onlyApprovedProcessor(_tokenId, msg.sender)
    {
        require(
            nut[_tokenId].nut_state == nutState.PendingProcess,
            "The nut has to be pending for process"
        );
        nut[_tokenId].nut_state = nutState.Processing;

        emit NutDelevered(approvedTransporter[_tokenId], msg.sender, _tokenId);
        // approvedTransporter[_tokenId] = address(0);
    }

    function storringNut(uint256 _tokenId)
        external
        onlyApprovedWarehouse(_tokenId, msg.sender)
    {
        require(
            nut[_tokenId].nut_state == nutState.PendingStorage,
            "The nut has to be pending for storage"
        );
        nut[_tokenId].nut_state = nutState.Stored;

        emit NutDelevered(approvedTransporter[_tokenId], msg.sender, _tokenId);
        // approvedTransporter[_tokenId] = address(0);
    }

    function burningNut(uint256 _tokenId)
        external
        onlyApprovedWarehouse(_tokenId, msg.sender)
    {
        require(
            nut[_tokenId].nut_state == nutState.Stored,
            "The nut has to be in stored"
        );
        nut[_tokenId].nut_state == nutState.Burned;

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

    function decreaseWeight(uint256 _weight_gram, uint256 _tokenId)
        public
        onlyApprovedProcessor(_tokenId, msg.sender)
        returns (uint256)
    {
        require(nut[_tokenId].nut_state == nutState.Processing);
        uint256 weight = nut[_tokenId].weight_gram;
        require(weight >= _weight_gram, "Weight can't be negative");

        console.log(
            "Decreasing weight of %s with amount of %s",
            weight.toString(),
            _weight_gram.toString()
        );

        nut[_tokenId].weight_gram = weight - _weight_gram;

        return nut[_tokenId].weight_gram;
    }

    function addISO(string memory _ISO, uint256 _tokenId)
        public
        onlyApprovedProcessor(_tokenId, msg.sender)
    {
        require(nut[_tokenId].nut_state == nutState.Processing);
        nut[_tokenId].ISO_list.push(_ISO);
    }

    function getISObyIndex(uint256 _tokenId, uint256 _ISOIndex)
        public
        view
        returns (string memory)
    {
        return nut[_tokenId].ISO_list[_ISOIndex];
    }

    function getISOLength(uint256 _tokenId) public view returns (uint256) {
        return nut[_tokenId].ISO_list.length;
    }

    function getNutState(uint256 _tokenId) public view returns (nutState) {
        return nut[_tokenId].nut_state;
    }

    function getNutType(uint256 _tokenId) public view returns (string memory) {
        return nut[_tokenId].nut_type;
    }

    function getNutWeight(uint256 _tokenId) public view returns (uint256) {
        return nut[_tokenId].weight_gram;
    }
}
