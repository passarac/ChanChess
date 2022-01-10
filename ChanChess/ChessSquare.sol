// SPDX-License-Identifier: UNLICENSED

import {ISquare} from "./interfaces/ISquare.sol";
import {ChessPieceType} from "./ChessPieceType.sol";

pragma solidity ^0.8.0;

contract ChessSquare is ISquare {
    struct ChessPiece {
        bool isWhite;
        ChessPieceType ID;
    }

    ChessPiece private piece;

    constructor(bool _isWhite, ChessPieceType _ID) {
        setPiece(_isWhite, _ID);
    }

    function isEmpty() public view override returns (bool) {
        return piece.ID == ChessPieceType.Empty;
    }

    function setPiece(bool _isWhite, ChessPieceType _ID)
        public
        override
        returns (bool)
    {
        piece.isWhite = _isWhite;
        piece.ID = _ID;

        return true;
    }

    function getID() public view override returns (ChessPieceType) {
        return piece.ID;
    }

    function isWhite() public view override returns (bool) {
        return piece.isWhite;
    }
}
