// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./TradeCoinV4.sol";
import "./RoleControl.sol";
import "./ITradeCoinComposition.sol";

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract TradeCoinComposition is
    ERC721,
    RoleControl,
    ReentrancyGuard,
    ITradeCoinComposition
{
    uint256 public tokenCounter;
    TradeCoinV4 public tradeCoinV4;

    struct Composition {
        uint256[] tokenIdsOfTC;
        uint256 cumulativeAmount;
        State state;
        bytes32 hashOfTransformations;
        address currentHandler;
    }

    modifier atState(State _state, uint256 _tokenId) {
        require(
            tradeCoinComposition[_tokenId].state == _state,
            "ProductNFT not in the right state"
        );
        _;
    }

    modifier notAtState(State _state, uint256 _tokenId) {
        require(
            tradeCoinComposition[_tokenId].state != _state,
            "ProductNFT can not be in the current state"
        );
        _;
    }

    modifier onlyLegalOwner(address _sender, uint256 _tokenId) {
        require(ownerOf(_tokenId) == _sender, "Sender is not owner of NFT.");
        _;
    }

    modifier isLegalOwnerOrCurrentHandler(address _sender, uint256 _tokenId) {
        require(
            tradeCoinComposition[_tokenId].currentHandler == _sender ||
                ownerOf(_tokenId) == _sender,
            "Given address is not the Owner nor current Handler."
        );
        _;
    }

    // Mapping for the metadata of the tradecoinComposition
    mapping(uint256 => Composition) public tradeCoinComposition;

    constructor(address _tradeCoinV4)
        ERC721("TradeCoinComposition", "TCC")
        RoleControl(msg.sender)
    {
        tradeCoinV4 = TradeCoinV4(payable(_tradeCoinV4));
    }

    function createComposition(
        string memory compositionName,
        uint256[] memory tokenIdsOfTC
    ) external override onlyTokenizer {
        require(
            tokenIdsOfTC.length > 1,
            "You can't make a composition of less then 2 tokens"
        );
        uint256 id = tokenCounter;

        uint256 totalWeight;
        for (uint256 i; i < tokenIdsOfTC.length; i++) {
            tradeCoinV4.transferFrom(
                msg.sender,
                address(this),
                tokenIdsOfTC[i]
            );

            (
                uint256 weightOfTC,
                TradeCoinV4.State stateOfProduct,
                ,

            ) = tradeCoinV4.tradeCoinCommodity(tokenIdsOfTC[i]);
            require(uint8(stateOfProduct) != 0, "Product still pending");
            totalWeight += weightOfTC;
        }

        // Mint new token
        _safeMint(msg.sender, id);
        // Store data on-chain
        tradeCoinComposition[id] = Composition(
            tokenIdsOfTC,
            totalWeight,
            State.Created,
            "",
            msg.sender
        );

        tokenCounter += 1;
        // Fire off the event
        emit MintComposition(
            id,
            msg.sender,
            tokenIdsOfTC,
            compositionName,
            totalWeight
        );
    }

    function appendProductToComposition(
        uint256 _tokenIdComposition,
        uint256 _tokenIdTC
    ) external override onlyTokenizer {
        // require(
        //     tradeCoinComposition[_tokenIdComposition].state ==
        //         State.PendingCreation,
        //     "This composition is already done"
        // );
        require(ownerOf(_tokenIdComposition) != address(0));

        tradeCoinV4.transferFrom(msg.sender, address(this), _tokenIdTC);

        tradeCoinComposition[_tokenIdComposition].tokenIdsOfTC.push(_tokenIdTC);

        (uint256 weightOfTC, , , ) = tradeCoinV4.tradeCoinCommodity(_tokenIdTC);
        tradeCoinComposition[_tokenIdComposition]
            .cumulativeAmount += weightOfTC;
    }

    function removeProductFromComposition(
        uint256 _tokenIdComposition,
        uint256 _indexTokenIdTC
    ) external override onlyTokenizer {
        uint256 lengthTokenIds = tradeCoinComposition[_tokenIdComposition]
            .tokenIdsOfTC
            .length;
        // require(
        //     tradeCoinComposition[_tokenIdComposition].state ==
        //         State.PendingCreation,
        //     "This composition is already done"
        // );
        require(lengthTokenIds > 2, "Can't remove token from composition");
        require((lengthTokenIds - 1) >= _indexTokenIdTC, "Index not in range");

        uint256 tokenIdTC = tradeCoinComposition[_tokenIdComposition]
            .tokenIdsOfTC[_indexTokenIdTC];
        uint256 lastTokenId = tradeCoinComposition[_tokenIdComposition]
            .tokenIdsOfTC[lengthTokenIds - 1];

        tradeCoinV4.transferFrom(address(this), msg.sender, tokenIdTC);

        tradeCoinComposition[_tokenIdComposition].tokenIdsOfTC[
            _indexTokenIdTC
        ] = lastTokenId;

        tradeCoinComposition[_tokenIdComposition].tokenIdsOfTC.pop();

        (uint256 weightOfTC, , , ) = tradeCoinV4.tradeCoinCommodity(tokenIdTC);
        tradeCoinComposition[_tokenIdComposition]
            .cumulativeAmount -= weightOfTC;
    }

    function decomposition(uint256 _tokenId) external override {
        require(ownerOf(_tokenId) == msg.sender, "You are not the owner");

        uint256[] memory productIds = tradeCoinComposition[_tokenId]
            .tokenIdsOfTC;
        for (uint256 i; i < productIds.length; i++) {
            tradeCoinV4.transferFrom(address(this), msg.sender, productIds[i]);
        }

        delete tradeCoinComposition[_tokenId];
        _burn(_tokenId);

        emit DecompositionOf(_tokenId, msg.sender, productIds);
    }

    function addTransformation(
        uint256 _tokenId,
        uint256 weightLoss,
        string memory _transformationCode
    )
        external
        override
        isLegalOwnerOrCurrentHandler(msg.sender, _tokenId)
        notAtState(State.NonExistent, _tokenId)
    {
        require(
            weightLoss <= tradeCoinComposition[_tokenId].cumulativeAmount,
            "Altered weight can't be more than total weight"
        );

        // tradeCoinComposition[_tokenId].transformations.push(
        //     _transformationCode
        // );
        uint256 newWeight = tradeCoinComposition[_tokenId].cumulativeAmount -
            weightLoss;
        tradeCoinComposition[_tokenId].cumulativeAmount = newWeight;

        emit CompositionTransformation(
            _tokenId,
            msg.sender,
            newWeight,
            _transformationCode
        );
    }

    function changeStateAndHandler(
        uint256 _tokenId,
        address _newCurrentHandler,
        State _newState
    )
        external
        override
        onlyLegalOwner(msg.sender, _tokenId)
        notAtState(State.NonExistent, _tokenId)
    {
        tradeCoinComposition[_tokenId].currentHandler = _newCurrentHandler;
        tradeCoinComposition[_tokenId].state = _newState;

        emit ChangeStateAndHandlerOf(
            _tokenId,
            msg.sender,
            _newState,
            _newCurrentHandler
        );
    }

    function splitProduct(uint256 _tokenId, uint256[] memory partitions)
        external
        override
        onlyLegalOwner(msg.sender, _tokenId)
        notAtState(State.NonExistent, _tokenId)
    {
        require(
            partitions.length <= 3 && partitions.length > 1,
            "Token should be split to 2 or more new tokens, we limit the max to 3."
        );
        // create temp list of tokenIds
        uint256[] memory tempArray = new uint256[](partitions.length + 1);
        tempArray[0] = _tokenId;
        // create temp struct
        Composition memory temporaryStruct = tradeCoinComposition[_tokenId];

        uint256 sumPartitions;
        for (uint256 x; x < partitions.length; x++) {
            require(partitions[x] != 0, "Partitions can't be 0");
            sumPartitions += partitions[x];
        }

        require(
            tradeCoinComposition[_tokenId].cumulativeAmount == sumPartitions,
            "The given amount of partitions do not equal total weight amount."
        );

        burnComposition(_tokenId);
        for (uint256 i; i < partitions.length; i++) {
            mintAfterSplitOrBatch(
                temporaryStruct.tokenIdsOfTC,
                // temporaryStruct.compositionName,
                partitions[i],
                temporaryStruct.state,
                temporaryStruct.currentHandler
                // temporaryStruct.transformations
            );
            tempArray[i + 1] = tokenCounter;
        }

        emit SplitComposition(_tokenId, msg.sender, tempArray);
        delete temporaryStruct;
    }

    function batchComposition(uint256[] memory _tokenIds) external override {
        require(
            _tokenIds.length > 1 && _tokenIds.length <= 3,
            "Maximum batch: 3, minimum: 2"
        );

        // bytes32 emptyHash;
        uint256 cumulativeWeight;
        uint256[] memory tokenIdsEmpty;
        Composition memory short = Composition(
            tokenIdsEmpty,
            0,
            State.Created,
            "",
            tradeCoinComposition[_tokenIds[0]].currentHandler
        );

        bytes32 hashed = keccak256(abi.encode(short));

        uint256[] memory tempArray = new uint256[](_tokenIds.length + 1);

        uint256[] memory collectiveProductIds = new uint256[](
            tradeCoinComposition[_tokenIds[0]].tokenIdsOfTC.length +
                tradeCoinComposition[_tokenIds[1]].tokenIdsOfTC.length
        );

        collectiveProductIds = concatenateArrays(
            tradeCoinComposition[_tokenIds[0]].tokenIdsOfTC,
            tradeCoinComposition[_tokenIds[0]].tokenIdsOfTC
        );

        for (uint256 tokenId; tokenId < _tokenIds.length; tokenId++) {
            require(
                ownerOf(_tokenIds[tokenId]) == msg.sender,
                "Unauthorized: The tokens do not have the same owner."
            );
            require(
                tradeCoinComposition[_tokenIds[tokenId]].state !=
                    State.NonExistent,
                "Unauthorized: The tokens are not in the right state."
            );
            Composition memory short2 = Composition(
                tokenIdsEmpty,
                0,
                tradeCoinComposition[_tokenIds[tokenId]].state,
                "",
                tradeCoinComposition[_tokenIds[tokenId]].currentHandler
            );
            require(
                hashed == keccak256(abi.encode(short2)),
                "This should be the same hash, one of the fields in the NFT don't match"
            );

            tempArray[tokenId] = _tokenIds[tokenId];
            // create temp struct
            cumulativeWeight += tradeCoinComposition[_tokenIds[tokenId]]
                .cumulativeAmount;
            burnComposition(_tokenIds[tokenId]);
            delete tradeCoinComposition[_tokenIds[tokenId]];
        }
        mintAfterSplitOrBatch(
            collectiveProductIds,
            // short.compositionName,
            cumulativeWeight,
            short.state,
            short.currentHandler
            // short.transformations
        );
        tempArray[_tokenIds.length] = tokenCounter;

        emit BatchComposition(msg.sender, tempArray);
    }

    function addInformation(uint256 _tokenId)
        external
        override
        onlyInformationHandler
        notAtState(State.NonExistent, _tokenId)
    {
        emit AddInformationTo(_tokenId, msg.sender);
    }

    function burnComposition(uint256 _tokenId)
        public
        virtual
        override
        onlyLegalOwner(msg.sender, _tokenId)
    {
        require(ownerOf(_tokenId) == msg.sender);
        for (
            uint256 i;
            i < tradeCoinComposition[_tokenId].tokenIdsOfTC.length;
            i++
        ) {
            tradeCoinV4.burnCommodity(
                tradeCoinComposition[_tokenId].tokenIdsOfTC[i]
            );
        }
        emit BurnComposition(
            _tokenId,
            msg.sender,
            tradeCoinComposition[_tokenId].tokenIdsOfTC
        );
        _burn(_tokenId);
        delete tradeCoinComposition[_tokenId];
    }

    function getIdsOfComposite(uint256 _tokenId)
        external
        view
        override
        returns (uint256[] memory)
    {
        return tradeCoinComposition[_tokenId].tokenIdsOfTC;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function mintAfterSplitOrBatch(
        uint256[] memory _tokenIdsOfProduct,
        uint256 _weight,
        State _state,
        address currentHandler
    ) internal {
        require(_weight != 0, "Weight can't be 0");

        uint256 id = tokenCounter;

        _safeMint(msg.sender, id);

        tradeCoinComposition[id] = Composition(
            _tokenIdsOfProduct,
            _weight,
            _state,
            "",
            currentHandler
        );

        tokenCounter += 1;
    }

    function concatenateArrays(
        uint256[] memory accounts,
        uint256[] memory accounts2
    ) internal pure returns (uint256[] memory) {
        uint256[] memory returnArr = new uint256[](
            accounts.length + accounts2.length
        );

        uint256 i = 0;
        for (; i < accounts.length; i++) {
            returnArr[i] = accounts[i];
        }

        uint256 j = 0;
        while (j < accounts.length) {
            returnArr[i++] = accounts2[j++];
        }

        return returnArr;
    }
}
