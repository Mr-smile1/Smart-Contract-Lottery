//SPDX-License-Identifier: MIT

pragma solidity ^0.6.6;


import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";


contract Lottery is VRFConsumerBase, Ownable {
    address payable[] public players;
    address payable public recentWinner;
    uint256 public randomness;
    uint256 public usdEntryFee;
    AggregatorV3Interface internal ethUsdPriceFeed;      //using chainlink ABI to convert 50$ to eth
    enum LOTTERY_STATE {
        OPEN,             
        CLOSED,
        CALCULATING_WINNER
    }
    // 0 ,1, 2

    LOTTERY_STATE public lottery_state;      // all for randomness requesting
    uint256 public fee;
    bytes32 public keyhash;
    event RequestedRandomness(bytes32 requestId);


    constructor(
        address _priceFeedAddress,
        address _vrfCoordinator,
        address _link,
        uint256 _fee,
        bytes32 _keyhash
        ) public VRFConsumerBase(_vrfCoordinator, _link) {
        usdEntryFee = 50 * (10**18);
        ethUsdPriceFeed = AggregatorV3Interface(_priceFeedAddress);
        lottery_state = LOTTERY_STATE.CLOSED;
        fee = _fee;
        keyhash = _keyhash;
    }

    function enter() public payable{           // to take fee
        //$50 min
        require(lottery_state == LOTTERY_STATE.OPEN);
        require(msg.value >= getEntranceFee(), "Not enough ETH!");
        players.push(msg.sender);
    }

    function getEntranceFee() public view returns (uint256){  // to take fee
        (, int256 price, , , ) = ethUsdPriceFeed.latestRoundData();
        uint256 adjustedPrice = uint256(price) * 10**10;
        // we need $50 and 1 eth = $2000
        // so 50/2000 
        // 50 * 100000 / 2000
        uint256 costToEnter = (usdEntryFee * 10**18) / adjustedPrice;
        return costToEnter;
        }

    function startLottery() public onlyOwner {                  //check if lottery is open or closed
        require(
            lottery_state == LOTTERY_STATE.CLOSED,
            "Can't start a new lottery yet!"
        );
        lottery_state = LOTTERY_STATE.OPEN;
    }

    function endLottery() public onlyOwner {           // request from chainlink for random value
        // not secure
        // uint256(
        //     keccack256(
        //         abi.encodePacked(
        //             nonce,               // nonce is preditable (aka, transaction number)
        //             msg.sender,          // msg.sender is predictable
        //             block.difficulty,    // can actually be manipulated by the miners!
        //             block.timestamp      // timestamp is predictable
        //         )
        //     )
        // ) % players.length;
        lottery_state = LOTTERY_STATE.CALCULATING_WINNER;            // no other transation will occur at this state
        bytes32 requestId = requestRandomness(keyhash, fee);         // 
        emit RequestedRandomness(requestId);
    }

 
    // chainlink will call a transation to the contract to send to random number 
    function fulfillRandomness(bytes32 _requestId, uint256 _randomness)       
        internal
        override
    {
        require(
            lottery_state == LOTTERY_STATE.CALCULATING_WINNER,
            "You aren't there yet!"
        );
        require(_randomness > 0, "random-not-found");
        uint256 indexOfWinner = _randomness % players.length;
        recentWinner = players[indexOfWinner];                      // got the winner 
        recentWinner.transfer(address(this).balance);               // send him lottery prize 
        // Reset
        players = new address payable[](0);
        lottery_state = LOTTERY_STATE.CLOSED; 
        randomness = _randomness;
    }

}

