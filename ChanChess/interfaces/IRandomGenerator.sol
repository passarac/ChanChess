// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

interface IRandomGenerator {
    function getRandomNumber() external returns (bytes32 requestId);
}
