// SPDX-License-Identifier: UNLICENSED

import {ChessPieceType} from "../ChessPieceType.sol";

pragma solidity ^0.8.0;

interface ISquare {
    function isEmpty() external view returns (bool);

    function setPiece(bool _isWhite, ChessPieceType _ID)
        external
        returns (bool);

    function getID() external view returns (ChessPieceType);

    function isWhite() external view returns (bool);
}
