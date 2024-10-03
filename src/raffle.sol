//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {VRFCoordinatorV2Interface} from "lib/chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2Plus} from "lib/chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "lib/chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 *@title A simple Raffle contract
 *@author Yassine Chtioui
 *@notice This is contract is for creating a simple raffle
 *@dev Implements Chainlink VRFv2.5
 */

contract Raffle is VRFConsumerBaseV2Plus {
    /**error*/
    error Raffle__sendMoreToEnterRaffle();
    error Raffle__notEnoughTimeHasPassed();
    error Raffle__transferFailed();
    error Raffle__raffleNotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 balance,
        uint256 playersLenght,
        uint256 raffleState
    );

    /**Type declaration */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /** State Variable */
    uint256 private immutable i_entranceFee;
    address payable[] private s_player;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    // @dev The duration of the lottery in seconds
    uint256 private immutable i_interval;
    uint256 private s_lastTimeStamp;

    // Chainlink VRF related variables
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_keyHash;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    /**Event */

    event RaffleEntered(address indexed player);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_interval = interval;
        i_entranceFee = entranceFee;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__sendMoreToEnterRaffle();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__raffleNotOpen();
        }
        s_player.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    /**
     * @dev This is the function that the Chainlink node will call if the lotery is ready to have a winner picked
     * the following should be true in order for upkeepNeeded to be true:
     * 1. the time interval has passed between raffle runs
     * 2. The lottery is open
     * 3. The contract has ETH
     * 4. Implicitly, your subscription has LINK
     * @param - ignored
     * @return upkeepNeed -true if it's time to restart the lottery
     * @return - ignored
     */

    function checkUpkeep(
        bytes calldata
    ) public view returns (bool upkeepNeeded, bytes memory) {
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) < i_interval);
        bool isOpen = (s_raffleState == RaffleState.OPEN);
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_player.length > 0;
        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;

        return (upkeepNeeded, "");
    }

    function performUpkeep(bytes memory /* performData*/) external {
        //Check to see if enough time has passed
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }

        //State change
        s_raffleState = RaffleState.CALCULATING;

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: true})
                )
            });

        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_player.length;
        address payable recentWinner = s_player[indexOfWinner];
        s_recentWinner = recentWinner;

        //States update
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(s_recentWinner);
        //Money transfer

        (bool succes, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__transferFailed();
        }
    }

    /** Getter functions */

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }
}
