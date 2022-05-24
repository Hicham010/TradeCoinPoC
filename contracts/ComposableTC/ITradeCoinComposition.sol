// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

interface ITradeCoinComposition {
    enum State {
        NonExistent,
        Created,
        PendingProcess,
        Processing,
        PendingTransport,
        Transporting,
        PendingStorage,
        Stored
    }

    event MintComposition(
        uint256 indexed tokenId,
        address indexed caller,
        uint256[] productIds,
        string compositionName,
        uint256 amount
    );

    event CompositionTransformation(
        uint256 indexed tokenId,
        address indexed caller,
        uint256 weightLoss,
        string transformation
    );

    event CompositionTransformation(
        uint256 indexed tokenId,
        address indexed caller,
        string transformation
    );

    event SplitComposition(
        uint256 indexed tokenId,
        address indexed caller,
        uint256[] newTokenIds
    );

    event BatchComposition(address indexed caller, uint256[] batchedTokenIds);

    event RemoveProductFromComposition(
        uint256 indexed tokenId,
        address indexed caller,
        uint256 tokenIdOfProduct
    );

    event AppendProductToComposition(
        uint256 indexed tokenId,
        address indexed caller,
        uint256 tokenIdOfProduct
    );

    event DecompositionOf(
        uint256 indexed tokenId,
        address indexed caller,
        uint256[] productIds
    );

    event ChangeStateAndHandlerOf(
        uint256 indexed tokenId,
        address indexed caller,
        State newState,
        address newCurrentHandler
    );

    event QualityCheckCommodity(
        uint256 indexed tokenId,
        address indexed checker,
        string data
    );

    event LocationOfCommodity(
        uint256 indexed tokenId,
        address indexed locationSignaler,
        uint256 latitude,
        uint256 longitude,
        uint256 radius
    );

    event AddInformationTo(uint256 indexed tokenId, address indexed caller);

    event BurnComposition(
        uint256 indexed tokenId,
        address indexed caller,
        uint256[] productIds
    );

    function createComposition(
        string memory compositionName,
        uint256[] memory tokenIdsOfTC
    ) external;

    function appendProductToComposition(
        uint256 _tokenIdComposition,
        uint256 _tokenIdTC
    ) external;

    function removeProductFromComposition(
        uint256 _tokenIdComposition,
        uint256 _indexTokenIdTC
    ) external;

    function decomposition(uint256 _tokenId) external;

    function addTransformation(
        uint256 _tokenId,
        uint256 weightLoss,
        string memory _transformationCode
    ) external;

    function changeStateAndHandler(
        uint256 _tokenId,
        address _newCurrentHandler,
        State _newState
    ) external;

    function splitProduct(uint256 _tokenId, uint256[] memory partitions)
        external;

    function batchComposition(uint256[] memory _tokenIds) external;

    function addInformation(uint256 _tokenId) external;

    function getIdsOfComposite(uint256 _tokenId)
        external
        view
        returns (uint256[] memory);

    function burnComposition(uint256 _tokenId) external;
}
