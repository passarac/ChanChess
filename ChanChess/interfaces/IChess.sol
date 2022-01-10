// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

interface IChess {
    event PlayerJoined(address player, bool isPlayerOne);
    event GameStarted(bool isPlayerOneWhite);

    event UnitPlaced(bool isPlayerOne);
    // event UnitMoved(bool isPlayerOne, uint256 oldLocation, uint256 newLocation);

    event UnitMoveRequested(
        bool isPlayerOne,
        uint256 oldLocation,
        uint256 newLocation
    );
    event UnitMoveRejected(
        bool isPlayerOne,
        uint256 oldLocation,
        uint256 newLocation
    );
    event UnitMoveAccepted(
        bool isPlayerOne,
        uint256 oldLocation,
        uint256 newLocation
    );

    event Strike(bool isPlayerOne);

    // event Checked(bool isPlayerOne);
    event Checkmate(bool isPlayerOne);
    event Stalemate(bool isPlayerOne);
    // event Won(bool isPlayerOne);

    event GameReset();
    event PlayerReset(address player);

    function joinGame() external payable returns (bool);

    function placeUnits() external returns (bool);

    function registerMove(uint256 oldLocation, uint256 newLocation)
        external
        returns (bool);

    function approveMove() external returns (bool);

    function disapproveMove() external returns (bool);

    function checkmate() external returns (bool);

    function stalemate() external returns (bool);

    function endGame() external returns (bool);

    function leaveGame() external returns (bool);

    function isEmpty(uint256 location) external view returns (bool);

    function getPieceAtLocation(uint256 location)
        external
        view
        returns (bytes32, bytes32);

    // function isChecked(address player) external view returns (bool);

    function isCheckmated(address player) external view returns (bool);

    function isStalemate(address player) external view returns (bool);

    function isGameEndable() external view returns (bool);

    function isWhite() external view returns (bool);

    function canMove(uint256 oldLocation, uint256 newLocation)
        external
        view
        returns (bool);

    function isTimeValid() external view returns (bool);

    function currentTurn() external view returns (bool);
}
