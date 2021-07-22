pragma solidity 0.6.12;

interface IContender { 
    function deanAnnounceWinner(uint256 gas) external;
    function getDividendTrackerContract() external returns (address payable);
    function deanRetractExtraBUSD() external;
}
