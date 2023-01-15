//SPDX-License-Identifier:MIT


pragma solidity ^0.8.0;
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";

error Lottery__NotEnoughETHEntered();
error Lottery__UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers,uint256 lotteryState);
error Lottery_NotOpen();
error Lottery__TransferFailed();

contract Lottery is VRFConsumerBaseV2 ,AutomationCompatibleInterface{

    enum LotteryState {
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
    LotteryState private s_lotteryState;
    uint256 private s_lastTimeStamp;
    uint256 private immutable i_interval;
    


    event LotteryEnter(address indexed player);
    event RequestedLotteryWinner( uint256 indexed requestId);
    event WinnerPicked(address indexed player);


    constructor (address vrfCoordinatorV2,
    uint256 entryFee,
    bytes32 gasLane,
    uint64 subscriptionId,
    uint32 callbackGasLimit, uint256 interval) 
    VRFConsumerBaseV2(vrfCoordinatorV2){
        entranceFee = entryFee;
        vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit= callbackGasLimit;
        s_lotteryState = LotteryState.OPEN;
        s_lastTimeStamp = block.timestamp;
        i_interval = interval;
    }


    function enterLottery() public payable {
        if(msg.value < entranceFee){
            revert Lottery__NotEnoughETHEntered();

        }
        if(s_lotteryState != LotteryState.OPEN){
            revert Lottery_NotOpen();
        }
        players.push(payable(msg.sender));
        emit LotteryEnter(msg.sender);

    }


    function checkUpkeep(bytes memory /*checkdata*/
    ) public override returns (bool upkeepNeeded, bytes memory /*PerformData*/) {
        bool isOpen = (LotteryState.OPEN== s_lotteryState);
        bool timePassed = ((block.timestamp - s_lastTimeStamp)> i_interval);
        bool hasPlayers = (players.length>0);
        bool hasBalance = address(this).balance>0;
        upkeepNeeded = (timePassed&&isOpen && hasBalance && hasPlayers);
        // return (upkeepNeeded,"0x00");
    }

    

    function performUpkeep(bytes calldata /*performData*/) external override{
        (bool upkeepNeeded,) = checkUpkeep(" ");
        if(!upkeepNeeded){
            revert Lottery__UpkeepNotNeeded(address(this).balance, players.length,uint256( s_lotteryState));
        }
        s_lotteryState = LotteryState.CALCULATING;
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
        s_lastTimeStamp = block.timestamp;
        s_lotteryState = LotteryState.OPEN;
        players = new address payable[](0);
        (bool success,) = recentWinner.call{value:address(this).balance}("");
        if (!success) {
            revert Lottery__TransferFailed();
        }
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
    function getLotteryState() public view returns (LotteryState){
        return s_lotteryState;
    }
    function getNumWords() public pure returns (uint256){
        return NUM_WORDS;
    }
    function getNumberOfPlayers() public view returns (uint256){
        return players.length;
    }
    function getLatestTimeStamp() public view returns (uint256){
        return s_lastTimeStamp;
    }
    function getRequestCOnfirmations() public pure returns (uint256){
        return REQUEST_CONFIRMATIONS;
    }

    function getInterval() public view returns(uint256){
        return i_interval;
    }

}
