// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";

/**
 * @title A simple Raffle Contract
 * @author Aakarshit Agarwal
 * @notice
 */
contract Raffle is VRFConsumerBaseV2, AutomationCompatibleInterface {
    /** Error */
    error Raffle__NotEnoughEthSent();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 currentBalance,
        uint256 numParticipants,
        uint256 raffleState
    );

    /** Events */
    event EnteredRaffle(address indexed participant);
    event PickedWinner(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    /** Type Declaration */
    enum RaffleState {
        OPEN,
        CALCULATING_WINNER
    }

    /** State Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_entranceFee;
    uint256 private immutable i_intervalInSeconds;
    VRFCoordinatorV2Interface private immutable i_vrfCordinator;
    bytes32 private immutable i_keyHash;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    uint256 private s_raffleStartTime;
    address payable[] private s_participants;
    address payable private s_winner;
    RaffleState private s_raffleState;

    /** Contructor */
    constructor(
        uint256 entranceFee,
        uint256 intervalInSeconds,
        address vrfCordinator,
        bytes32 keyHash,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCordinator) {
        i_entranceFee = entranceFee;
        i_intervalInSeconds = intervalInSeconds;
        s_raffleStartTime = block.timestamp;
        i_vrfCordinator = VRFCoordinatorV2Interface(vrfCordinator);
        i_keyHash = keyHash;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
    }

    /** Payable Functions */
    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEthSent();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        s_participants.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    /* Getter Functions*/
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    /** Other Functions */
    function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory /*performData*/)
    {
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool timePassed = ((block.timestamp - s_raffleStartTime) >
            i_intervalInSeconds);
        bool hasPlayers = s_participants.length > 0;
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (isOpen && timePassed && hasPlayers && hasBalance);
        // return (upkeepNeeded, "");
    }

    function performUpkeep(
        bytes memory callData /* performData */
    ) external override {
        (bool upkeepNeeded, ) = checkUpkeep(callData);
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_participants.length,
                uint256(s_raffleState)
            );
        }

        s_raffleState = RaffleState.CALCULATING_WINNER;
        uint256 requestId = i_vrfCordinator.requestRandomWords(
            i_keyHash,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        // TODO: Get the random number
        uint256 winnerParticipantIndex = randomWords[0] % s_participants.length;
        address payable winner = s_participants[winnerParticipantIndex];
        s_winner = winner;

        // Reset Lottery
        s_raffleState = RaffleState.OPEN; // Shouldn't this be moved to success of transaction below?
        s_participants = new address payable[](0);
        s_raffleStartTime = block.timestamp;

        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
        emit PickedWinner(winner);
    }
}
