// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.3;
// import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
// import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
// import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
// import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
// import "@openzeppelin/contracts/utils/Counters.sol";
// import "./RoleControl.sol";
// import "hardhat/console.sol";

// contract TradeCoinERC721 is
//     ERC721,
//     ERC721Enumerable,
//     ERC721Burnable,
//     Ownable,
//     RoleControl
// {
//     constructor(string memory _name, string memory _symbol)
//         ERC721(_name, _symbol)
//         RoleControl(_msgSender())
//     {}

//     using Strings for uint256;
//     // SafeMath and Counters for creating unique ProductNFT identifiers
//     // incrementing the tokenID by 1 after each mint
//     using Counters for Counters.Counter;
//     Counters.Counter private _tokenIdCounter;

//     // structure of the metadata
//     struct TradeCoin {
//         string commodity;
//         uint256 weight; // in grams
//         State state;
//         address currentHandler;
//         string[] transformations;
//         string rootHash; //TODO: roothash should be saved in the logs not struct. Because we don't do anything with it.
//     }

//     // Mapping for the metadata of the tradecoin
//     mapping(uint256 => TradeCoin) public tradeCoin;
//     // Optional mapping for token URIs
//     mapping(uint256 => string) private _tokenURIs;

//     mapping(uint256 => address) public addressOfNewOwner;
//     mapping(uint256 => uint256) public priceForOwnership;
//     mapping(uint256 => bool) public paymentInFiat;

//     // Definition of Events
//     event productPending(address indexed creator, uint256 indexed _tokenId);
//     //TODO: save the (indexed) hashes as bytes32 not strings
//     event productCreated(
//         address indexed seller,
//         address indexed receiver,
//         uint256 indexed _tokenId
//     );

//     event offering(
//         uint256 indexed _tokenId,
//         address indexed _sender,
//         string indexed _docHash,
//         string _docType,
//         string _rootHash,
//         bool payInFiat
//     );

//     event transformation(
//         address indexed _sender,
//         uint256 indexed _tokenId,
//         string indexed _docHash,
//         string _docType,
//         string _rootHash,
//         uint256 _weightLoss,
//         string _transformationCode
//     );

//     event handlerAndStateUpdate(
//         uint256 indexed _tokenId,
//         address indexed _sender,
//         string indexed _docHash,
//         string _docType,
//         string _rootHash,
//         State _newState,
//         address _newCurrentHandler
//     );

//     event productSplit(uint256[] indexed _tokenIds, address indexed _sender);
//     event split(
//         uint256 indexed splittedTokenId,
//         uint256 indexed newTokenFromSplit
//     );

//     event productBatched(uint256[] indexed _tokenIds, address indexed _sender);

//     event productBought(
//         address indexed _seller,
//         address indexed _buyer,
//         uint256 indexed _tokenId
//     );

//     event productBurned(
//         address indexed productConsumer,
//         uint256 indexed _tokenId
//     );

//     event rootHashUpdate(
//         uint256 indexed _tokenId,
//         string indexed _docHash,
//         string indexed _rootHash
//     );

//     // Enum of state of productNFT
//     enum State {
//         PendingCreation,
//         Created,
//         PendingProcess,
//         Processing,
//         PendingTransport,
//         Transporting,
//         PendingStorage,
//         Stored,
//         Burned,
//         EOL //end of life
//     }

//     // Setting default to creation
//     State public state = State.PendingCreation;
//     string[] public basicTransformation;
//     uint256[] public array;

//     // Self created modifiers/require
//     modifier atState(State _state, uint256 tokenId) {
//         require(
//             tradeCoin[tokenId].state == _state,
//             "ProductNFT not in the right status"
//         );
//         _;
//     }
//     //TODO: you don't need to pass the state. You can just hardcode in because of the name.
//     modifier notAtPendingCreation(State _state, uint256 tokenId) {
//         require(
//             tradeCoin[tokenId].state != _state,
//             "ProductNFT can not in the current status"
//         );
//         _;
//     }

//     modifier onlyNFTOwner(address sender, uint256 tokenId) {
//         require(ownerOf(tokenId) == sender, "Sender is not owner of NFT.");
//         _;
//     }

//     modifier isLegalOwnerOrCurrentHandler(address sender, uint256 _tokenId) {
//         require(
//             tradeCoin[_tokenId].currentHandler == sender ||
//                 ownerOf(_tokenId) == sender,
//             "Given address is not the Owner nor current Handler."
//         );
//         _;
//     }

//     modifier isOwnerOrApproved(address sender, uint256 tokenId) {
//         require(
//             _isApprovedOrOwner(sender, tokenId),
//             "Given address is not the Owner nor approved."
//         );
//         _;
//     }

//     modifier onlyApprovedTransporterState(uint256 _tokenId) {
//         require(
//             tradeCoin[_tokenId].state == State.Transporting ||
//                 tradeCoin[_tokenId].state == State.PendingTransport,
//             "Is not set to transporting or pending"
//         );
//         _;
//     }

//     modifier onlyApprovedProcessorState(uint256 _tokenId) {
//         require(
//             tradeCoin[_tokenId].state == State.Processing ||
//                 tradeCoin[_tokenId].state == State.PendingProcess,
//             "Is not set to processing or pending"
//         );
//         _;
//     }

//     modifier onlyApprovedWarehouseState(uint256 _tokenId) {
//         require(
//             tradeCoin[_tokenId].state == State.Stored ||
//                 tradeCoin[_tokenId].state == State.PendingStorage,
//             "Is not set to stored or pending"
//         );
//         _;
//     }

//     // Function must be overridden as ERC721 and ERC721Enumerable are conflicting
//     function _beforeTokenTransfer(
//         address from,
//         address to,
//         uint256 tokenId
//     ) internal override(ERC721, ERC721Enumerable) {
//         super._beforeTokenTransfer(from, to, tokenId);
//     }

//     // Function must be overridden as ERC721 and ERC721Enumerable are conflicting
//     function supportsInterface(bytes4 interfaceId)
//         public
//         view
//         override(ERC721, ERC721Enumerable, AccessControl)
//         returns (bool)
//     {
//         return super.supportsInterface(interfaceId);
//     }

//     // Helper function to convert hexstrings/addresses to string
//     function addressToString(address _address)
//         public
//         pure
//         returns (string memory)
//     {
//         bytes32 _bytes = bytes32(uint256(uint160(_address)));
//         bytes memory HEX = "0123456789abcdef";
//         bytes memory _string = new bytes(42);
//         _string[0] = "0";
//         _string[1] = "x";
//         for (uint256 i; i < 20; i++) {
//             _string[2 + i * 2] = HEX[uint8(_bytes[i + 12] >> 4)];
//             _string[3 + i * 2] = HEX[uint8(_bytes[i + 12] & 0x0f)];
//         }
//         return string(_string);
//     }

//     // Set new baseURI
//     function _baseURI()
//         internal
//         view
//         virtual
//         override(ERC721)
//         returns (string memory)
//     {
//         return "http://tradecoin.nl/vault/";
//     }

//     // Set token URI
//     function _setTokenURI(uint256 tokenId, string memory _tokenURI)
//         internal
//         virtual
//     {
//         require(
//             _exists(tokenId),
//             "ERC721Metadata: URI set of nonexistent token"
//         );
//         _tokenURIs[tokenId] = _tokenURI;
//     }

//     // We have a seperate tokenization function for the first time minting, we mint this value to the Farmer address
//     function initialTokenization(
//         string memory commodity,
//         // weight in gram
//         uint256 weight,
//         // value given by application
//         string memory rootHash
//     ) public onlyTokenizerOrAdmin {
//         //TODO: 0 check
//         require(weight >= 0, "Weight can't be 0 or less");
//         //TODO: Why is this needed do it clien side. And converting to bytes and checking on length is better.
//         require(
//             keccak256(abi.encodePacked(commodity)) !=
//                 keccak256(abi.encodePacked("")),
//             "Commodity needs to have a value."
//         );
//         require(
//             keccak256(abi.encodePacked(rootHash)) !=
//                 keccak256(abi.encodePacked("")),
//             "RootHash can't be empty."
//         );
//         // Set default transformations to raw
//         //TODO: why do we do this? Use new uint[]()
//         basicTransformation.push("Raw");

//         // Get new tokenId by incrementing
//         _tokenIdCounter.increment();
//         uint256 id = _tokenIdCounter.current();

//         // Mint new token
//         _safeMint(_msgSender(), id);
//         // Store data on-chain
//         tradeCoin[id] = TradeCoin(
//             commodity,
//             weight,
//             state,
//             _msgSender(),
//             basicTransformation,
//             rootHash
//         );
//         delete basicTransformation;
//         _setTokenURI(id, id.toString());
//         // Fire off the event
//         emit productPending(msg.sender, id);
//     }

//     function initiateCommercialTx(
//         uint256 _tokenId,
//         uint256 priceInEth,
//         address newOwner,
//         string memory _docHash,
//         string memory _docType,
//         string memory _rootHash,
//         bool payInFiat
//     ) external onlyNFTOwner(_msgSender(), _tokenId) {
//         require(_msgSender() != newOwner, "You can't sell to yourself");
//         if (payInFiat) {
//             require(priceInEth == 0, "You promised to pay in Fiat.");
//         }

//         priceForOwnership[_tokenId] = (priceInEth) * 1 ether; //TODO: use ethers instead of 1e18
//         addressOfNewOwner[_tokenId] = newOwner;
//         paymentInFiat[_tokenId] = payInFiat;
//         tradeCoin[_tokenId].rootHash = _rootHash;

//         emit offering(
//             _tokenId,
//             _msgSender(),
//             _docHash,
//             _docType,
//             _rootHash,
//             payInFiat
//         );
//     }

//     // warehouse to product handler
//     function approveTokenization(uint256 _tokenId)
//         external
//         payable
//         onlyProductHandlerOrAdmin
//         atState(State.PendingCreation, _tokenId)
//     {
//         require(
//             addressOfNewOwner[_tokenId] == msg.sender,
//             "You don't have the right to pay"
//         );
//         require(
//             priceForOwnership[_tokenId] <= msg.value,
//             "You did not pay enough"
//         );

//         address addrOwner = ownerOf(_tokenId);

//         // When not paying in Fiat pay but in Eth
//         if (!paymentInFiat[_tokenId]) {
//             require(priceForOwnership[_tokenId] != 0, "The can't be sold");
//             payable(addrOwner).transfer(msg.value);
//         }
//         // else transfer
//         _transfer(addrOwner, msg.sender, _tokenId);
//         // TODO: DISCUSS: Should we also reset the currentHandler to a new address?

//         // Change state and delete memory
//         delete priceForOwnership[_tokenId];
//         delete addressOfNewOwner[_tokenId];
//         tradeCoin[_tokenId].state = State.Created;

//         emit productCreated(addrOwner, msg.sender, _tokenId);
//     }

//     // Can only be called if Owner or approved account
//     // In case of being an approved account, this account must be a Minter Role and Burner Role (Admin)
//     //TODO: what if you want to do multiple transformation in one tx?
//     function addTransformation(
//         uint256 _tokenId,
//         uint256 weightLoss,
//         string memory _transformationCode,
//         string memory _docHash,
//         string memory _docType,
//         string memory _rootHash
//     ) public isLegalOwnerOrCurrentHandler(_msgSender(), _tokenId) {
//         //TODO: this require will result in true even if weightloss is 0
//         require(
//             weightLoss >= 0 && weightLoss <= tradeCoin[_tokenId].weight,
//             "Altered weight can't be 0 nor more than total weight"
//         );
//         //TODO: What happens when you make a mistake?
//         tradeCoin[_tokenId].transformations.push(_transformationCode);
//         uint256 newWeight = tradeCoin[_tokenId].weight - weightLoss;
//         tradeCoin[_tokenId].weight = newWeight;
//         tradeCoin[_tokenId].rootHash = _rootHash;

//         emit transformation(
//             _msgSender(),
//             _tokenId,
//             _docHash,
//             _docType,
//             _rootHash,
//             newWeight,
//             _transformationCode
//         );
//     }

//     function changeStateAndHandler(
//         uint256 _tokenId,
//         address _newCurrentHandler,
//         State _newState,
//         string memory _docHash,
//         string memory _docType,
//         string memory _rootHash
//     ) public onlyNFTOwner(_msgSender(), _tokenId) {
//         tradeCoin[_tokenId].currentHandler = _newCurrentHandler;
//         tradeCoin[_tokenId].state = _newState;
//         tradeCoin[_tokenId].rootHash = _rootHash;

//         emit handlerAndStateUpdate(
//             _tokenId,
//             _msgSender(),
//             _docHash,
//             _docType,
//             _rootHash,
//             _newState,
//             _newCurrentHandler
//         );
//     }

//     function burn(uint256 _tokenId)
//         public
//         virtual
//         override(ERC721Burnable)
//         onlyNFTOwner(_msgSender(), _tokenId)
//     {
//         _burn(_tokenId);
//         // Remove lingering data to refund gas costs
//         delete tradeCoin[_tokenId];
//         emit productBurned(msg.sender, _tokenId);
//     }

//     function splitProduct(uint256 _tokenId, uint256[] memory partitions)
//         public
//         onlyNFTOwner(_msgSender(), _tokenId)
//         //TODO: should you also be able split when a product is transporting or pending process for example?
//         notAtPendingCreation(State.PendingCreation, _tokenId)
//     {
//         require(
//             partitions.length <= 3 && partitions.length > 1,
//             "Token should be split to 2 or more new tokens, we limit the max to 3."
//         );
//         //TODO: use new uint[]() instead of global list
//         // create temp list of tokenIds
//         array.push(_tokenId);
//         // create temp struct
//         TradeCoin memory temporaryStruct = tradeCoin[_tokenId];

//         uint256 sumPartitions;
//         for (uint256 x; x < partitions.length; x++) {
//             require(partitions[x] != 0, "Partitions can't be 0");
//             sumPartitions += partitions[x];
//         }

//         require(
//             tradeCoin[_tokenId].weight == sumPartitions,
//             "The given amount of partitions do not equal total weight amount."
//         );

//         burn(_tokenId);
//         for (uint256 i; i < partitions.length; i++) {
//             mintUniqueProductBatch(
//                 temporaryStruct.commodity,
//                 partitions[i],
//                 temporaryStruct.state,
//                 temporaryStruct.currentHandler,
//                 temporaryStruct.transformations,
//                 temporaryStruct.rootHash
//             );
//             array.push(_tokenId + i + 1);
//             // emit splitProduct(_tokenId, array[i]);
//         }

//         emit productSplit(array, _msgSender());
//         delete array;
//         delete temporaryStruct;
//     }

//     function batchProduct(uint256[] memory _tokenIds) public {
//         require(
//             _tokenIds.length > 1 && _tokenIds.length <= 3,
//             "Maximum batch: 3, minimum: 2"
//         );
//         //TODO: add also a check for state

//         uint256 cummulativeWeight;
//         string memory commodity = tradeCoin[_tokenIds[0]].commodity;
//         State currentState = tradeCoin[_tokenIds[0]].state;
//         address currentHandler = tradeCoin[_tokenIds[0]].currentHandler;
//         string[] memory transformations = tradeCoin[_tokenIds[0]]
//             .transformations;
//         string memory rootHash = tradeCoin[_tokenIds[0]].rootHash;

//         bytes32 hashed = keccak256(
//             abi.encode(
//                 commodity,
//                 currentState,
//                 currentHandler,
//                 transformations,
//                 rootHash
//             )
//         );

//         for (uint256 tokenId; tokenId < _tokenIds.length; tokenId++) {
//             require(
//                 ownerOf(_tokenIds[tokenId]) == _msgSender(),
//                 "Unauthorized: The tokens do not have the same owner."
//             );
//             require(
//                 hashed ==
//                     keccak256(
//                         abi.encode(
//                             tradeCoin[_tokenIds[tokenId]].commodity,
//                             tradeCoin[_tokenIds[tokenId]].state,
//                             tradeCoin[_tokenIds[tokenId]].currentHandler,
//                             tradeCoin[_tokenIds[tokenId]].transformations,
//                             ""
//                         )
//                     ),
//                 "This should be the same hash, one of the fields in the NFT don't match"
//             );
//             array.push(tokenId);
//             // create temp struct
//             cummulativeWeight += tradeCoin[_tokenIds[tokenId]].weight;
//             burn(_tokenIds[tokenId]);
//             delete tradeCoin[_tokenIds[tokenId]];
//         }
//         mintUniqueProductBatch(
//             commodity,
//             cummulativeWeight,
//             currentState,
//             currentHandler,
//             transformations,
//             rootHash
//         );

//         emit productBatched(array, _msgSender());
//         delete array;
//     }

//     // This function will mint a token to
//     function mintUniqueProductBatch(
//         string memory _commodity,
//         uint256 _weight,
//         State _state,
//         address currentHandler,
//         string[] memory transformations,
//         string memory rootHash
//     ) public onlyProductHandlerOrAdmin {
//         require(_weight != 0, "Weight can't be 0");
//         //TODO: do the same as in previous empty string check (convert to bytes)
//         require(
//             keccak256(abi.encodePacked(_commodity)) !=
//                 keccak256(abi.encodePacked("")),
//             "Commodity needs to have a value."
//         );

//         // Get new tokenId by incrementing
//         _tokenIdCounter.increment();
//         uint256 id = _tokenIdCounter.current();

//         // Mint new token
//         _safeMint(_msgSender(), id);
//         // Store data on-chain
//         tradeCoin[id] = TradeCoin(
//             _commodity,
//             _weight,
//             _state,
//             currentHandler,
//             transformations,
//             rootHash
//         );

//         _setTokenURI(id, id.toString());

//         // Fire off the event
//         emit productPending(msg.sender, id);
//     }

//     function finishCommercialTransaction(uint256 _tokenId) public payable {
//         require(
//             addressOfNewOwner[_tokenId] == msg.sender,
//             "You don't have the right to pay"
//         );
//         require(
//             priceForOwnership[_tokenId] <= msg.value,
//             "You did not pay enough"
//         );
//         address addrOwner = ownerOf(_tokenId);

//         // When not paying in Fiat pay but in Eth
//         if (!paymentInFiat[_tokenId]) {
//             require(
//                 priceForOwnership[_tokenId] != 0,
//                 "This can't be sold for 0 eth"
//             );
//             payable(addrOwner).transfer(msg.value);
//         }
//         // else transfer
//         _transfer(addrOwner, msg.sender, _tokenId);
//         // TODO: DISCUSS: Should we also reset the currentHandler t

//         // Change state and delete memory
//         delete priceForOwnership[_tokenId];
//         delete addressOfNewOwner[_tokenId];

//         emit productBought(addrOwner, msg.sender, _tokenId);
//     }

//     function updateRootHash(
//         uint256 _tokenId,
//         string memory _docHash,
//         string memory _rootHash
//     ) public onlyInformationHandlerOrAdmin {
//         tradeCoin[_tokenId].rootHash = _rootHash;

//         emit rootHashUpdate(_tokenId, _docHash, _rootHash);
//     }

//     function getISObyIndex(uint256 _tokenId, uint256 _isoIndex)
//         public
//         view
//         returns (string memory)
//     {
//         return tradeCoin[_tokenId].transformations[_isoIndex];
//     }

//     function getISOLength(uint256 _tokenId) public view returns (uint256) {
//         return tradeCoin[_tokenId].transformations.length;
//     }
// }
