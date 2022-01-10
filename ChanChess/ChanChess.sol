// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import {IChess} from "./interfaces/IChess.sol";
import {IChessRandom} from "./interfaces/IChessRandom.sol";
import {IRandomGenerator} from "./interfaces/IRandomGenerator.sol";
import {IController} from "./interfaces/IController.sol";

import {ChessPieceType} from "./ChessPieceType.sol";
import {ChessSquare} from "./ChessSquare.sol";

contract ChanChess is IChess, IChessRandom {
    enum State {
        WAITING_PLAYERS_JOIN,
        WAITING_CHOOSE_WHITE,
        WAITING_PLAYERS_PLACE,
        IN_GAME_WAITING_REQUEST_MOVE,
        IN_GAME_WAITING_APPROVAL_MOVE,
        END_GAME
    }

    State private state;
    bool private p1IsWhite;

    bool private p1PlacedUnits;
    bool private p2PlacedUnits;

    bool private p1Turn;

    mapping(uint256 => ChessSquare) public board;

    address private immutable owner;
    address private p1;
    address private p2;

    mapping(address => uint256) private balances;
    mapping(address => uint256) private strikes;

    uint256 private timeSinceLastPlayed;
    uint256 constant maxTimeToMakeMove = 300;

    uint256 constant costToPlay = 1 ether;
    uint256[2] private currentMoves;

    IController private controller;

    constructor(address _controller) {
        owner = msg.sender;
        controller = IController(_controller);
    }

    function joinGame()
        external
        payable
        override
        onlyWaitingPlayers
        returns (bool)
    {
        require(msg.value >= costToPlay, "Need 1 ether to play");
        require(
            p1 == address(0) || p1 != msg.sender,
            "You already joined the game"
        );

        if (p1 == address(0)) {
            p1 = msg.sender;
        } else {
            p2 = msg.sender;
        }

        balances[msg.sender] = costToPlay;
        strikes[msg.sender] = 0;

        emit PlayerJoined(msg.sender, p1 == msg.sender);

        if (p2 != address(0)) {
            startGame();
        }
        return true;
    }

    function placeUnits()
        external
        override
        onlySettingUp
        onlyPlayers
        returns (bool)
    {
        if (msg.sender == p1) {
            // Pawns
            uint256 i = 0;
            for (i = 8; i < 16; i++) {
                board[i] = new ChessSquare(p1IsWhite, ChessPieceType.Pawn);
            }

            //Rooks
            //Knights
            //Bishops
            //...
            p1PlacedUnits = true;
        } else {
            // Pawns
            //Rooks
            //Knights
            //Bishops
            //...
            p2PlacedUnits = true;
        }

        emit UnitPlaced(msg.sender == p1);

        if (p1PlacedUnits && p2PlacedUnits) {
            state = State.IN_GAME_WAITING_REQUEST_MOVE;

            // Move elsewhere like at reset code
            p1PlacedUnits = false;
            p2PlacedUnits = false;
        }

        timeSinceLastPlayed = block.timestamp;

        return true;
    }

    function registerMove(uint256 oldLocation, uint256 newLocation)
        external
        override
        onlyInGameWaitingRequest
        onlyPlayers
        onlyLowStrikes
        returns (bool)
    {
        require((msg.sender == p1) == p1Turn, "It is not your turn");

        require(isTimeValid(), "Time over. End game.");

        require(!isCheckmated(msg.sender), "You are checkmated. Game over.");

        require(!board[oldLocation].isEmpty(), "No piece at the location");

        bool currentPlayerWhite = isWhite();
        require(
            board[oldLocation].isWhite() == currentPlayerWhite,
            "Cannot control enemy unit"
        );

        // This can fail for switching rook with King (very special case)
        if (!board[newLocation].isEmpty()) {
            // Do extra check for switch rook with king
            // If ID...
            require(
                board[oldLocation].isWhite() != board[newLocation].isWhite(),
                "New position contains player's own pieces"
            );
        }

        state = State.IN_GAME_WAITING_APPROVAL_MOVE;

        currentMoves[0] = oldLocation;
        currentMoves[1] = newLocation;

        // Change time
        timeSinceLastPlayed = block.timestamp;

        // Emit event
        emit UnitMoveRequested((msg.sender == p1), oldLocation, newLocation);

        return true;
    }

    function approveMove()
        external
        override
        onlyInGameWaitingApproval
        onlyPlayers
        onlyLowStrikes
        returns (bool)
    {
        require((msg.sender == p1) != p1Turn, "You cannot approve own moves");

        move(currentMoves[0], currentMoves[1]);

        p1Turn = !p1Turn;

        state = State.IN_GAME_WAITING_REQUEST_MOVE;

        emit UnitMoveAccepted(p1Turn, currentMoves[0], currentMoves[1]);

        return true;
    }

    function disapproveMove()
        external
        override
        onlyInGameWaitingApproval
        onlyPlayers
        onlyLowStrikes
        returns (bool)
    {
        require(
            (msg.sender == p1) != p1Turn,
            "You cannot disapprove own moves"
        );

        bool res = canMove(currentMoves[0], currentMoves[1]);

        // Strike for mistake
        if (res) {
            strike(msg.sender != p1);
            return false;
        }

        // Punish other
        strike(msg.sender == p1);

        state = State.IN_GAME_WAITING_REQUEST_MOVE;

        emit UnitMoveRejected(p1Turn, currentMoves[0], currentMoves[1]);

        return true;
    }

    function checkmate()
        external
        override
        onlyInGame
        onlyPlayers
        returns (bool)
    {
        bool res;

        // Check if isCheckmated
        if (msg.sender == p1) {
            res = isCheckmated(p2);
        } else {
            res = isCheckmated(p1);
        }

        // Strike for mistake
        if (!res) {
            strike(msg.sender == p1);
            return false;
        }

        // Punish other
        strike(msg.sender != p1);

        // Set game to end
        state = State.END_GAME;

        emit Checkmate((msg.sender == p1));

        return true;
    }

    function stalemate()
        external
        override
        onlyInGame
        onlyPlayers
        returns (bool)
    {
        bool res;

        // Check if isCheckmated
        if (msg.sender == p1) {
            res = isStalemate(p2);
        } else {
            res = isStalemate(p1);
        }

        // Strike for mistake
        if (!res) {
            strikes[msg.sender] += 1;
            return false;
        }

        // Punish other
        strike(msg.sender != p1);

        // Set game to end
        state = State.END_GAME;

        emit Stalemate((msg.sender == p1));

        return true;
    }

    function endGame()
        external
        override
        onlyInGameOrEnd
        onlyPlayers
        onlyLowStrikes
        returns (bool)
    {
        require(isGameEndable(), "Game is not endable");

        // Find why it ended and who ended

        // Set money to send back to player
        uint256 amountWithdrawn = balances[msg.sender];
        balances[msg.sender] = 0;
        // If end due to strike, add other player balance in

        // If end due to strike, resetGame for both players
        // else Reset game for ourself only
        resetGame(false);

        // Send money
        (bool success, ) = payable(msg.sender).call{value: amountWithdrawn}("");
        require(success, "Failed to send Ether");

        // Emit winner isPlayerOne=true/false
        // emit Won(true);

        return true;
    }

    function leaveGame() external override onlyPlayers returns (bool) {
        resetGame(false);

        return true;
    }

    function resetGame(bool resetBoth) private returns (bool) {
        if (resetBoth) {
            //reset both
        } else if (msg.sender == p1) {
            p1 = address(0);
            // reset board for p1
        } else if (msg.sender == p2) {
            p2 = address(0);
            // reset board for p2
        }
        emit PlayerReset(msg.sender);

        if (p1 == p2 && p1 == address(0)) {
            state = State.WAITING_PLAYERS_JOIN;
            emit GameReset();
        }

        return true;
    }

    function isEmpty(uint256 location)
        external
        view
        override
        onlyInGame
        returns (bool)
    {
        require(location < 64, "Location must be within 8x8 aka 0->63");

        return (board[location].isEmpty());
    }

    function getPieceAtLocation(uint256 location)
        external
        view
        override
        onlyInGame
        returns (bytes32, bytes32)
    {
        require(location < 64, "Location must be within 8x8 aka 0->63");

        ChessPieceType pieceID = board[location].getID();

        bytes32 b_pieceID;
        if (pieceID == ChessPieceType.Pawn) {
            b_pieceID = "Pawn";
        } else if (pieceID == ChessPieceType.Rook) {
            b_pieceID = "Rook";
        } else if (pieceID == ChessPieceType.Knight) {
            b_pieceID = "Knight";
        } else if (pieceID == ChessPieceType.Bishop) {
            b_pieceID = "Bishop";
        } else if (pieceID == ChessPieceType.Queen) {
            b_pieceID = "Queen";
        } else if (pieceID == ChessPieceType.King) {
            b_pieceID = "King";
        }

        bytes32 b_pieceColor;
        if (board[location].isWhite()) {
            b_pieceColor = "White";
        } else {
            b_pieceColor = "Black";
        }

        return (b_pieceID, b_pieceColor);
    }

    // function isChecked(address player)
    //     public
    //     view
    //     override
    //     onlyInGame
    //     returns (bool)
    // {
    //     require(player == p1 || player == p2, "Address is not a player");

    //     // check checked or not
    //     return true;
    // }

    function isCheckmated(address player)
        public
        view
        override
        onlyInGame
        onlyPlayers
        returns (bool)
    {
        // check checkmated or not
        return true;
    }

    function isStalemate(address player)
        public
        view
        override
        onlyInGame
        onlyPlayers
        returns (bool)
    {
        // check stalemate or not
        return true;
    }

    function isGameEndable()
        public
        view
        override
        onlyInGameOrEnd
        onlyPlayers
        returns (bool)
    {
        if (state == State.END_GAME) return true;

        if (!isTimeValid()) return true;

        if (strikes[p1] >= 2 || strikes[p2] >= 2) return true;

        if (isCheckmated(p1) || isCheckmated(p2)) return true;

        return false;
    }

    function canMove(uint256 oldLocation, uint256 newLocation)
        public
        view
        override
        onlyInGame
        returns (bool)
    {
        require(oldLocation != newLocation, "Cannot move to own position");
        //Check if piece can move to new position
        // Make sure this does not caused "checked" status
        // IF isChecked(msg.sender), make sure the movement removes checked status
        return true;
    }

    function isTimeValid() public view override returns (bool) {
        return (timeSinceLastPlayed + maxTimeToMakeMove > block.timestamp);
    }

    function isWhite()
        public
        view
        override
        onlyReadyOrInGame
        onlyPlayers
        returns (bool)
    {
        if (msg.sender == p1) {
            return p1IsWhite;
        } else {
            return !p1IsWhite;
        }
    }

    function currentTurn()
        external
        view
        override
        onlyReadyOrInGame
        returns (bool)
    {
        if (msg.sender == p1) {
            return p1Turn;
        } else {
            return !p1Turn;
        }
    }

    function startGame() private returns (bool) {
        state = State.WAITING_CHOOSE_WHITE;

        // Randomly pick player
        IRandomGenerator(controller.GetRandomGeneratorAddress())
            .getRandomNumber();

        return true;
    }

    function move(uint256 oldLocation, uint256 newLocation) private {
        // Move to new position
        board[newLocation].setPiece(
            board[oldLocation].isWhite(),
            board[oldLocation].getID()
        );

        // Set old position to empty
        board[oldLocation].setPiece(
            board[oldLocation].isWhite(),
            ChessPieceType.Empty
        );
    }

    function strike(bool isPlayerOne) private {
        if (isPlayerOne) {
            strikes[p1] += 1;
        } else {
            strikes[p2] += 1;
        }

        emit Strike(isPlayerOne);
    }

    function fulfill_random(uint256 randomness)
        external
        override
        onlyDuringChooseWhite
    {
        require(
            msg.sender == controller.GetRandomGeneratorAddress(),
            "Only random generator can call"
        );
        if (randomness % 2 == 0) {
            p1IsWhite = true;
        } else {
            p1IsWhite = false;
        }
        p1Turn = p1IsWhite;

        state = State.WAITING_PLAYERS_PLACE;

        emit GameStarted(p1IsWhite);
    }

    modifier onlyWaitingPlayers() {
        require(
            state == State.WAITING_PLAYERS_JOIN,
            "Game has already started"
        );
        _;
    }

    modifier onlyReadyOrInGame() {
        require(state != State.WAITING_PLAYERS_JOIN, "Game is not ready");
        _;
    }

    modifier onlySettingUp() {
        require(
            state == State.WAITING_PLAYERS_PLACE,
            "Game has not yet finished setup"
        );
        _;
    }

    modifier onlyDuringChooseWhite() {
        require(
            state == State.WAITING_CHOOSE_WHITE,
            "Game not ready to choose"
        );
        _;
    }

    modifier onlyInGame() {
        require(
            state == State.IN_GAME_WAITING_APPROVAL_MOVE ||
                state == State.IN_GAME_WAITING_REQUEST_MOVE,
            "Game has not yet started"
        );
        _;
    }

    modifier onlyInGameOrEnd() {
        require(
            state == State.IN_GAME_WAITING_APPROVAL_MOVE ||
                state == State.IN_GAME_WAITING_REQUEST_MOVE ||
                state == State.END_GAME,
            "Game has not yet started"
        );
        _;
    }

    modifier onlyInGameWaitingRequest() {
        require(
            state == State.IN_GAME_WAITING_REQUEST_MOVE,
            "Game is not ready for request"
        );
        _;
    }

    modifier onlyInGameWaitingApproval() {
        require(
            state == State.IN_GAME_WAITING_APPROVAL_MOVE,
            "Game is not ready for approval"
        );
        _;
    }

    modifier onlyPlayers() {
        require(
            (msg.sender == p1 || msg.sender == p2),
            "Only players can interact"
        );
        _;
    }

    modifier onlyLowStrikes() {
        require(strikes[msg.sender] < 2, "Too many strikes");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owners can interact");
        _;
    }
}
