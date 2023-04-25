// SPDX-License-Identifier: UNLICENSED
//

pragma solidity =0.8.17;

import "./stakeBase.sol";

contract StakeERC20 is StakeBase {
    // erc20 token address for swap of v2
    address public immutable lpToken;

    struct StakingERC20 {
        uint256 amount; // lp token amount
        uint256 score; // score of the amount
        uint256 beginNo; // as week number, contained
        uint256 endNo; // as week number, not contained
        uint256 toClaimNo; //the latest week number to claim
    }
    // the current index id to stake
    uint256 public nonce;
    // id => stakingERC20, it will be delete when it's withdrew
    mapping(uint256 => StakingERC20) public stakingERC20s;
    // user address => ids of stakingERC20s
    mapping(address => uint256[]) public userERC20s;

    event Stake(address indexed user, uint256 id, uint256 amount, uint8 k);
    event Withdraw(address indexed user, uint256 amount);
    event ClaimReward(address indexed user, uint256 amount);

    constructor(
        uint8 maxWeeks,
        uint256 maxScale,
        address _rewardToken,
        address _lpToken
    ) StakeBase(maxWeeks, maxScale, _rewardToken) {
        lpToken = _lpToken;
    }

    /// @dev stake erc20 token of `amount` for k weeks
    /// @param amount transfer erc20 token to this contract
    /// @param k stake the token for k weeks
    function stake(uint256 amount, uint8 k) external {
        require(k > 0 && k <= MAX_WEEKS, "k 1~52");
        _safeTransferFrom(lpToken, msg.sender, address(this), amount);
        uint256 weekNumber = block.timestamp / WEEK_SECONDS + 1;
        uint256 score = getScore(amount, k);

        // add score to totalScore of every week
        for (uint8 i = 0; i < k; i++) {
            totalScores[weekNumber + i] += score;
        }

        stakingERC20s[nonce] = StakingERC20(
            amount,
            score,
            weekNumber,
            weekNumber + k,
            weekNumber
        );

        userERC20s[msg.sender].push(nonce);
        emit Stake(msg.sender, nonce, amount, k);
        nonce++;
    }

    /// @dev withdraw token to the caller, if the amount is not enough, it will be as close as possible
    /// @param amount the token amount
    /// @return total the real amount of erc20 token transfered
    function withdraw(uint256 amount) external returns (uint256 total) {
        uint256 weekNumber = block.timestamp / WEEK_SECONDS;
        for (uint256 i = userERC20s[msg.sender].length - 1; i >= 0; i--) {
            // foreach every StakingERC20 from the last one
            uint id = userERC20s[msg.sender][i];
            if (stakingERC20s[id].endNo <= weekNumber) {
                // when the staking erc20 token expire
                total += stakingERC20s[id].amount;
                if (total <= amount) {
                    // if total is not bigger than amount, delete the staking token
                    userERC20s[msg.sender][i] = userERC20s[msg.sender][
                        userERC20s[msg.sender].length
                    ];
                    userERC20s[msg.sender].pop();
                } else {
                    // modify the amount of stakingERC20 to the left
                    stakingERC20s[id].amount = total - amount;
                    total = amount;
                }
                if (total == amount) {
                    break;
                }
            }
        }
        _safeTransfer(lpToken, msg.sender, total);
        emit Withdraw(msg.sender, total);
        return total;
    }

    /// @dev claim all the rewards for user's stakingERC20s
    function claimReward() external {
        uint256 weekNumber = block.timestamp / WEEK_SECONDS;
        uint256 total = 0;
        for (uint256 i = 0; i < userERC20s[msg.sender].length; i++) {
            uint256 id = userERC20s[msg.sender][i];
            for (
                uint256 no = stakingERC20s[id].toClaimNo;
                no < stakingERC20s[id].endNo;
                no++
            ) {
                if (
                    bClaimReward[id][no] || // cann't be claimed
                    no > weekNumber || // cann't be over current week number
                    rewardsOf[no] == 0 // cann't claim which don't set
                ) {
                    continue;
                }
                bClaimReward[id][no] = true;
                stakingERC20s[id].toClaimNo = no + 1;
                total +=
                    (rewardsOf[no] * stakingERC20s[id].score) /
                    totalScores[no];
            }
        }
        _safeTransfer(rewardToken, msg.sender, total);
        emit ClaimReward(msg.sender, total);
    }

    /// @dev get the amount of user is staking
    /// @return total all amount of lp token in this contract
    /// @return staking the staking amount of lp token in this contract
    function getStaking()
        external
        view
        returns (uint256 total, uint256 staking)
    {
        uint256 weekNumber = block.timestamp / WEEK_SECONDS;
        for (uint256 i = 0; i < userERC20s[msg.sender].length; i++) {
            uint256 id = userERC20s[msg.sender][i];
            uint256 amount = stakingERC20s[id].amount;
            if (stakingERC20s[id].endNo > weekNumber) {
                staking += amount;
            }
            total += amount;
        }
        return (total, staking);
    }
}
