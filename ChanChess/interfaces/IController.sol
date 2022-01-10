// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

interface IController {
    event Initiated();

    function GetChanChessAddress() external view returns (address);

    function GetRandomGeneratorAddress() external view returns (address);
}
