pragma solidity 6.12;

interface IContender { 
    function deanAnnounceWinner(uint256 gas) public;
    function getDividendTrackerContract() public returns (address payable);
}