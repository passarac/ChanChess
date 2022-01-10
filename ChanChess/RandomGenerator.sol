// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "./vrf/VRFConsumerBase.sol";
import {IRandomGenerator} from "./interfaces/IRandomGenerator.sol";
import {IController} from "./interfaces/IController.sol";
import {IChessRandom} from "./interfaces/IChessRandom.sol";

contract RandomGenerator is VRFConsumerBase, IRandomGenerator {
    bytes32 public reqId;
    uint256 public randomNumber;

    bytes32 internal keyHash;
    uint256 internal fee;

    IController private controller;

    constructor(
        address _vrfCoordinator,
        address _link,
        address _controller,
        bytes32 _keyHash
    ) VRFConsumerBase(_vrfCoordinator, _link) {
        keyHash = _keyHash;
        fee = 0.1 * 10**18; // 0.1 LINK (Varies by network)

        controller = IController(_controller);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness)
        internal
        override
    {
        reqId = requestId;
        randomNumber = randomness;

        IChessRandom(controller.GetChanChessAddress()).fulfill_random(
            randomness
        );
    }

    /**
     * Requests randomness
     */
    function getRandomNumber() public returns (bytes32 requestId) {
        require(
            LINK.balanceOf(address(this)) >= fee,
            "Not enough LINK - fill contract with faucet"
        );
        require(
            msg.sender == controller.GetChanChessAddress(),
            "Only ChanChess can call"
        );
        return requestRandomness(keyHash, fee);
    }
}
