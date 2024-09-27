//SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;
/**
 *@title A simple Raffle contract
 *@author Yassine Chtioui
 *@notice This is contract is for creating a simple raffle
 *@dev Implements Chainlink VRFv2.5
 */

contract Raffle {
    /**error*/

    error Raffle__sendMoreToEnterRaffle();

    uint256 private immutable i_entranceFee;
    address payable[] private s_player;
    // @dev The duration of the lottery in seconds
    uint256 private immutable i_interval;
    uint256 private s_lastTimeStamp;

    /**Event */

    event RaffleEntered(address indexed player);

    constructor(uint256 entranceFee, uint256 interval) {
        i_interval = interval;
        i_entranceFee = entranceFee;
        s_lastTimeStamp = block.timestamp;
    }

    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__sendMoreToEnterRaffle();
        }
        s_player.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    function pickWinner() external {
        //Check to see if enough time has passed
        if ((block.timestamp - s_lastTimeStamp) < i_interval) {
            revert();
        }

        //Get our random number
    }

    /** Getter functions */

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }
}
