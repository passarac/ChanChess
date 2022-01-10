// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import {IController} from "./interfaces/IController.sol";

contract Controller is IController {
    bool private initiable;
    address private ChanChess;
    address private RandomGenerator;

    constructor() {
        initiable = true;
    }

    function init(address _ChanChess, address _RandomGenerator) external {
        require(_ChanChess != address(0), "ChanChess address missing");
        require(
            _RandomGenerator != address(0),
            "RandomGenerator address missing"
        );
        require(initiable, "Can only be called once");
        initiable = false;
        RandomGenerator = _RandomGenerator;
        ChanChess = _ChanChess;

        emit Initiated();
    }

    function GetChanChessAddress() external view returns (address) {
        return ChanChess;
    }

    function GetRandomGeneratorAddress() external view returns (address) {
        return RandomGenerator;
    }
}
