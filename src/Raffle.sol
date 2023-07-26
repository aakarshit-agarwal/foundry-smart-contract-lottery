// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/**
 * @title A simple Raffle Contract
 * @author Aakarshit Agarwal
 * @notice
 */
contract Raffle {
    /** Error */
    error Raffle__NotEnoughEthSent();

    /** Events */
    event EnteredRaffle(address indexed participant);

    uint256 private immutable i_entranceFee;
    uint256 private immutable i_intervalInSeconds;
    uint256 private immutable i_raffleStartTime;
    address payable[] private i_participants;

    /** Contructor */
    constructor(uint256 entranceFee, uint256 intervalInSeconds) {
        i_entranceFee = entranceFee;
        i_intervalInSeconds = intervalInSeconds;
        i_raffleStartTime = block.timestamp;
    }

    /** Payable Functions */
    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthSent();
        }
        i_participants.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    /* Getter Functions*/
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function pickWinner() external {
        if (block.timestamp < i_raffleStartTime + i_intervalInSeconds) {
            revert();
        }
    }
}
