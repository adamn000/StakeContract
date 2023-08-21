// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract StakeContract {
    error AmountMustBeMoreThanZero();
    error TransferFailed();
    error AmountExceedsStakedBalance();

    // Amount of tokens generated every second
    uint256 public immutable i_rewardRate;

    // Store last update of block.timestamp
    uint256 public s_lastUpdate;
    // Actual reward per one token staked in the pool
    uint256 public s_rewardPerTokenStaked;
    // Actual amount of tokens staked in the pool
    uint256 public s_totalStaked;

    // Store earned tokens
    mapping(address => uint256) private s_userRewardPerTokenPaid;
    // Rewards earned by user from staking
    mapping(address => uint256) private s_userRewards;
    // Balance of token staked by user
    mapping(address => uint256) private s_userStakedBalance;

    constructor(uint256 rewardRate) {
        i_rewardRate = rewardRate;
    }

    //** The modifier is used in stake and withdraw function to keep track users balances */
    modifier updateReward(address user) {
        s_rewardPerTokenStaked = rewardPerTokenStaked();
        s_lastUpdate = block.timestamp;
        s_userRewards[user] = userReward(user);
        s_userRewardPerTokenPaid[user] = s_rewardPerTokenStaked;
        _;
    }

    /**
     * Stake function allows user to stake token in the pool and starting earn rewards
     */
    function stake(address token, uint256 amount) external updateReward(msg.sender) {
        if (amount <= 0) {
            revert AmountMustBeMoreThanZero();
        }

        s_userStakedBalance[msg.sender] += amount;
        s_totalStaked += amount;

        bool success = IERC20(token).transferFrom(msg.sender, address(this), amount);
        if (!success) {
            revert TransferFailed();
        }
    }

    /**
     * Withdraw function allows user to withdraw tokens staked in the pool
     */
    function withdraw(address token, uint256 amount) external updateReward(msg.sender) {
        if (amount <= 0) {
            revert AmountMustBeMoreThanZero();
        }

        s_userStakedBalance[msg.sender] -= amount;
        s_totalStaked -= amount;

        bool success = IERC20(token).transfer(msg.sender, amount);
        if (!success) {
            revert TransferFailed();
        }
    }

    /**
     * Calculating user reward from staking tokens
     */
    function userReward(address user) public view returns (uint256) {
        uint256 userStakedBalance = s_userStakedBalance[user];
        uint256 userRewardPerTokenPaid = s_userRewardPerTokenPaid[user];
        uint256 userRewards = s_userRewards[user];
        return ((userStakedBalance * (rewardPerTokenStaked() - userRewardPerTokenPaid)) / 1e18) + userRewards;
    }

    /**
     * Function calculating actual reward per each token staked, depends of amount of token staked in the pool
     */
    function rewardPerTokenStaked() public view returns (uint256) {
        if (s_totalStaked == 0) {
            return s_rewardPerTokenStaked;
        }
        uint256 stakeTime = block.timestamp - s_lastUpdate;

        return s_rewardPerTokenStaked + (i_rewardRate * stakeTime * 1e18) / s_totalStaked;
    }
    /**
     * This function allows users to claim the rewards
     */

    function claimReward(address token) external updateReward(msg.sender) {
        uint256 reward = s_userRewards[msg.sender];
        if (reward > 0) {
            s_userRewards[msg.sender] = 0;
            IERC20(token).transfer(msg.sender, reward);
        }
    }

    /**
     * View Functions
     */
    function getUserStakeBalance(address user) external view returns (uint256) {
        return s_userStakedBalance[user];
    }

    function getTotalStakedBalance() external view returns (uint256) {
        return s_totalStaked;
    }

    function getUserRewards(address user) external view returns (uint256) {
        return s_userRewards[user];
    }
}
