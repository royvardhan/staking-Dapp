// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;  //Do not change the solidity version as it negativly impacts submission grading

import "hardhat/console.sol";
import "./ExampleExternalContract.sol";

error Staker__NotEnoughEthSent();

contract Staker {

  event Stake(address indexed sender, uint256 amount);
  event Received(address, uint256);
  event Execute(address indexed sender, uint256 amount);


  mapping(address => uint256) public balances;
  mapping(address => uint256) public depositTimestamps;

  ExampleExternalContract public exampleExternalContract;
  uint256 public constant rewardPerSecond = 0.1 ether;
  uint256 public withdrawDeadline = block.timestamp + 120 seconds;
  uint256 public claimDeadline = block.timestamp + 240 seconds;
  uint256 public currentBlock = 0;

  constructor(address exampleExternalContractAddress) {
      exampleExternalContract = ExampleExternalContract(exampleExternalContractAddress);
  }

  modifier withdrawalDeadlineReached(bool requireReached) {
    uint256 timeRemaining = withdrawalTimeleft();
    if ( requireReached ) {
      require(timeRemaining == 0, "Withdrawal period is not reached yet");
    } else {
      require(timeRemaining > 0, "Withdrawal Period has been reached");
    }
    _;
  }

  modifier claimDeadlineReached(bool requireReached) {
    uint256 timeRemaining = claimTimeleft();
    if ( requireReached ) {
      require(timeRemaining == 0, "Claim deadline is not reached yet");
    } else {
      require(timeRemaining > 0, "Claim deadline has been reached");
    }
    _;
  }

  modifier notCompleted() {
    bool completed = exampleExternalContract.completed();
    require(!completed, "Stake already completed");
    _;
  }

  function withdrawalTimeleft() public view returns(uint256 withdrawaltimeleft) {
    if (block.timestamp >= withdrawDeadline) {
      return (0);
    } else {
        return (withdrawDeadline - block.timestamp);
      }
  }

  function claimTimeleft() public view returns(uint256 claimtimeleft) {
    if (block.timestamp >= claimDeadline) {
      return (0);
    } else {
        return (claimDeadline - block.timestamp);
      }
  }

  function stake() public payable withdrawalDeadlineReached(false) claimDeadlineReached(false) {
    if (msg.value < 0.1 ether) {
      revert Staker__NotEnoughEthSent();
    }
    depositTimestamps[msg.sender] = block.timestamp;
    balances[msg.sender] = msg.value;
    emit Stake(msg.sender, msg.value);
  }

  function withdraw() public withdrawalDeadlineReached(true) claimDeadlineReached(false) notCompleted {
    require(balances[msg.sender] > 0, "You have not staked any funds yet");
    uint256 individualBalance = balances[msg.sender];
    uint256 individualRewards = individualBalance + ((block.timestamp - depositTimestamps[msg.sender]) * rewardPerSecond);
    balances[msg.sender] = 0;

    //Tranferring the ETH via call

    (bool sent, bytes memory data) = msg.sender.call{value: individualRewards}("");
    require(sent, "Whoa bruh, wihtdrawal failed");
  }

  /*
  Allows any user to repatriate "unproductive" funds that are left in the staking contract
  past the defined withdrawal period
  */
  
  function execute() public claimDeadlineReached(true) notCompleted {
    uint256 contractBalance = address(this).balance;
    exampleExternalContract.complete{value: contractBalance}();
  }

  /*
  \Function for our smart contract to receive ETH
  cc: https://docs.soliditylang.org/en/latest/contracts.html#receive-ether-function
  */
  receive() external payable {
      emit Received(msg.sender, msg.value);
  }


}
