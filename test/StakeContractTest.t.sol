// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/StakeContract.sol";
import "../src/Token.sol";
import "../script/DeployStakeContract.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract CounterTest is Test {
    StakeContract public stakeContract;
    DeployStakeContract public deployStakeContract;

    ERC20 public token;

    address public user = address(1);
    address public user2 = address(2);

    uint256 public constant STAKE_AMOUNT = 1 ether;
    uint256 public constant WITHDRAW_AMOUNT = 1 ether;

    function setUp() public {
        deployStakeContract = new DeployStakeContract();
        (token, stakeContract) = deployStakeContract.run();
        token = new Token();
        token.transfer(address(this), 5e18);
        token.transfer(user, 5e18);
        token.transfer(user2, 5e18);
    }

    //*** Stake Functions Tests ***/

    modifier staked() {
        vm.startPrank(user);
        token.approve(address(stakeContract), STAKE_AMOUNT);
        stakeContract.stake(address(token), STAKE_AMOUNT);
        vm.stopPrank();
        _;
    }

    function testUserCanStakeAndHaveStakeBalance() public staked {
        vm.startPrank(user2);
        token.approve(address(stakeContract), STAKE_AMOUNT * 2);
        stakeContract.stake(address(token), STAKE_AMOUNT * 2);
        vm.stopPrank();

        assert(stakeContract.getUserStakeBalance(user) == STAKE_AMOUNT);
        assert(stakeContract.getUserStakeBalance(user2) == STAKE_AMOUNT * 2);
        assert(stakeContract.s_totalStaked() == STAKE_AMOUNT * 3);
    }

    //*** Calculating users rewards test ***/

    function testCalculatingRewardsPerActualAmountOfTokenStaked() public staked {
        vm.warp(block.number + 10);
        // 10 tokens per second => 100 tokens per 10 seconds * tokensStaked(1) = 100
        assert(stakeContract.rewardPerTokenStaked() == 100);
    }

    function testCalculateUsersRewardsWithDifferentStakeAmount() public staked {
        vm.startPrank(user2);
        token.approve(address(stakeContract), STAKE_AMOUNT * 3);
        stakeContract.stake(address(token), STAKE_AMOUNT * 3);
        vm.stopPrank();

        vm.warp(block.timestamp + 20); // 200 token per 20 seconds
        // user1 staked 25% of totalStaked - earned 25% * 200 = 50
        //user2 staked 75% of totalStaked - earned 75% * 200 = 150

        console.log(stakeContract.userReward(user));

        assert(stakeContract.userReward(user) == 50);
        assert(stakeContract.userReward(user2) == 150);
    }

    function testCalculateUsersRewardsWithDifferentTimeStaked() public staked {
        vm.warp(block.timestamp + 10);

        vm.startPrank(user2);
        token.approve(address(stakeContract), 3 * STAKE_AMOUNT);
        stakeContract.stake(address(token), 3 * STAKE_AMOUNT);
        vm.stopPrank();
        vm.warp(block.timestamp + 10);

        assert(stakeContract.userReward(user) == 125);
        assert(stakeContract.userReward(user2) == 75);
    }

    //*** Withdraw test ***/

    function testUserCanWithdrawStakedTokens() public staked {
        uint256 startingUserWalletBalance = token.balanceOf(user);
        uint256 startingUserStakeBalance = stakeContract.getUserStakeBalance(user);

        vm.prank(user);
        stakeContract.withdraw(address(token), WITHDRAW_AMOUNT);

        uint256 userWalletBalance = token.balanceOf(user);
        uint256 userStakeBalance = stakeContract.getUserStakeBalance(user);

        assert(userWalletBalance == startingUserWalletBalance + WITHDRAW_AMOUNT);
        assert(userStakeBalance == startingUserStakeBalance - WITHDRAW_AMOUNT);
    }

    //*** ClaimReward Test ***/

    function testUserCanClaimRewardsFromStaking() public staked {
        uint256 startingUserWalletBalance = token.balanceOf(user);
        uint256 expectedRewards = 100;
        vm.warp(block.timestamp + 10);

        vm.prank(user);
        stakeContract.claimReward(address(token));

        uint256 userWalletBalance = token.balanceOf(user);

        assert(userWalletBalance == startingUserWalletBalance + expectedRewards);
        assert(stakeContract.userReward(user) == 0);
        assert(stakeContract.getUserRewards(user) == 0);
    }
}
