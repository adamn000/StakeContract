// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Token.sol";
import "../src/StakeContract.sol";
import "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract DeployStakeContract is Script {
    Token public token;
    StakeContract public stakeContract;

    uint256 rewardRate = 10;

    function run() external returns (Token, StakeContract) {
        vm.startBroadcast();
        token = new Token();
        stakeContract = new StakeContract(rewardRate);
        vm.stopBroadcast();
        return (token, stakeContract);
    }
}
