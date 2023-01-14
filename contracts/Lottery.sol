//SPDX-License-Identifier:MIT


pragma solidity ^0.8.0;
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

error Lottery__NotEnoughETHEntered();

contract Lottery is VRFConsumerBaseV2 {

    enum RaffleState {
        OPEN,
        CALCULATING
    }
    

    uint256 private immutable entranceFee;
    address payable[] private players;
    VRFCoordinatorV2Interface private immutable vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    uint16 private constant REQUEST_CONFIRMATIONS=3;
    uint32 private constant NUM_WORDS = 1;

    address private s_recentWinner;


    event LotteryEnter(address indexed player);
    event RequestedLotteryWinner( uint256 indexed requestId);
    event WinnerPicked(address indexed player);


    constructor (address vrfCoordinatorV2,
    uint256 entryFee,
    bytes32 gasLane,
    uint64 subscriptionId,
    uint32 callbackGasLimit) 
    VRFConsumerBaseV2(vrfCoordinatorV2){
        entranceFee = entryFee;
        vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit= callbackGasLimit;
    }


    function enterLottery() public payable {
        if(msg.value < entranceFee){
            revert Lottery__NotEnoughETHEntered();

        }
        players.push(payable(msg.sender));
        emit LotteryEnter(msg.sender);

    }

    function requestRandomWinner() external {
        uint256 requestId = vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit RequestedLotteryWinner(requestId);

    }
    function fulfillRandomWords(uint256, uint256[] memory randomWords) internal override {
        uint256 indexOfWinner = randomWords[0] % players.length;
        address payable recentWinner = players[indexOfWinner];
        s_recentWinner = recentWinner;
        (bool success,) = recentWinner.call{value:address(this).balance}("");
        emit WinnerPicked(recentWinner);


    }


    function getEntranceFee() public view returns (uint256) {
        return entranceFee;
    }
    function getPlayer(uint256 index)public view returns (address ){
        return players[index];
    }
    function  getRecentWinner() public view returns(address){
        return s_recentWinner;
    }

}
