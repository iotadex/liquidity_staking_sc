// SPDX-License-Identifier: UNLICENSED
//

pragma solidity =0.8.17;

import "./ownable.sol";

contract StakeBase is Ownable {
    // token address, to set by the owner
    address public immutable rewardToken;
    // user address => week number => score
    mapping(address => mapping(uint256 => uint256)) public userScores;
    //user address => [begin week number, end week number]
    mapping(address => uint256[2]) public userCanClaimWeeks;

    // weekNumber => score
    mapping(uint256 => uint256) public totalScores;
    // the owner to set, week number => reward token amount
    mapping(uint256 => uint256) public rewardsOf;
    // the lastest week number
    uint256 public latestNo;

    uint8 public immutable MAX_WEEKS;
    uint256 public immutable MAX_SCALE;
    uint24 public constant WEEK_SECONDS = 600;
    uint8 public immutable LOCK_WEEKNUM;
    uint256 public immutable BEGIN_TIME;
    uint256 public immutable END_TIME;

    event SetReward(address indexed user, uint256 no, uint256 amount);
    event ClaimReward(address indexed user, uint256 amount);

    constructor(
        uint8 maxWeeks,
        uint256 maxScale,
        uint8 lockWeeks,
        uint256 beginTime,
        uint256 endTime,
        address _rewardToken
    ) {
        rewardToken = _rewardToken;
        MAX_WEEKS = maxWeeks;
        MAX_SCALE = maxScale;
        LOCK_WEEKNUM = lockWeeks;
        BEGIN_TIME = beginTime;
        END_TIME = endTime;

        owner = msg.sender;
    }

    /// @dev set rewardToken to this contract, with transfering token
    /// @param no the week number
    /// @param amount the reward amount for rewardToken
    function setReward(uint256 no, uint256 amount) external {
        require(msg.sender == owner, "forbidden");
        _safeTransferFrom(rewardToken, msg.sender, address(this), amount);
        rewardsOf[no] += amount;
        if (no > latestNo) {
            latestNo = no;
        }
        emit SetReward(msg.sender, no, amount);
    }

    /// @dev set rewardToken to this contract, with transfering token
    /// @param nos the week numbers
    /// @param amounts the reward amounts for rewardToken
    /// @return total total amount of rewards
    function setRewards(
        uint256[] memory nos,
        uint256[] memory amounts
    ) external returns (uint256 total) {
        require(msg.sender == owner, "forbidden");
        require(nos.length == amounts.length, "parameters error");
        for (uint256 i = 0; i < nos.length; i++) {
            total += amounts[i];
            rewardsOf[nos[i]] = amounts[i];
            if (nos[i] > latestNo) {
                latestNo = nos[i];
            }
        }
        _safeTransferFrom(rewardToken, msg.sender, address(this), total);
        emit SetReward(msg.sender, 0, total);
    }

    function withdrawRewards(uint256 amount) external {
        require(msg.sender == owner, "forbidden");
        _safeTransfer(rewardToken, msg.sender, amount);
    }

    /// @dev claim all the rewards for user's stakingERC20s
    function claimReward() external {
        uint256 weekNumber = block.timestamp / WEEK_SECONDS - LOCK_WEEKNUM;
        uint256 total = 0;
        for (
            uint256 no = userCanClaimWeeks[msg.sender][0];
            no < userCanClaimWeeks[msg.sender][1];
            no++
        ) {
            // cann't be over the locked week number
            if (no > weekNumber) {
                break;
            }
            userCanClaimWeeks[msg.sender][0] = no + 1;
            total +=
                (rewardsOf[no] * userScores[msg.sender][no]) /
                totalScores[no];
        }
        _safeTransfer(rewardToken, msg.sender, total);
        emit ClaimReward(msg.sender, total);
    }

    function canClaimAmount() public view returns (uint256) {
        uint256 weekNumber = block.timestamp / WEEK_SECONDS - LOCK_WEEKNUM;
        uint256 total = 0;
        for (
            uint256 no = userCanClaimWeeks[msg.sender][0];
            no < userCanClaimWeeks[msg.sender][1];
            no++
        ) {
            // cann't be over the locked week number
            if (no > weekNumber) {
                break;
            }
            total +=
                (rewardsOf[no] * userScores[msg.sender][no]) /
                totalScores[no];
        }
        return total;
    }

    function lockedRewardAmount()
        public
        view
        returns (uint256, uint256[] memory)
    {
        uint256 weekNumber = block.timestamp / WEEK_SECONDS - LOCK_WEEKNUM + 1;
        if (userCanClaimWeeks[msg.sender][1] <= weekNumber) {
            return (weekNumber, new uint256[](0));
        }
        uint256[] memory amountList = new uint256[](
            userCanClaimWeeks[msg.sender][1] - weekNumber
        );
        for (
            uint256 no = weekNumber;
            no < userCanClaimWeeks[msg.sender][1];
            no++
        ) {
            amountList[no - weekNumber] =
                (rewardsOf[no] * userScores[msg.sender][no]) /
                totalScores[no];
        }
        return (weekNumber, amountList);
    }

    /// @dev get the score for amount and k by using a liner equation
    /// @param amount the amount of token to stake
    /// @param k is the x of equation
    /// @return score is the y of equation
    function getScore(
        uint256 amount,
        uint8 k
    ) public view returns (uint256 score) {
        score =
            (amount * ((MAX_SCALE - 1) * (k - 1) + MAX_WEEKS - 1)) /
            (MAX_WEEKS - 1);
    }

    /// @dev safe tranfer erc20 token frome address(this) to address
    function _safeTransfer(address token, address to, uint256 value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0xa9059cbb, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "TRANSFER_FAILED"
        );
    }

    /// @dev safe tranfer erc20 token from address to address
    function _safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0x23b872dd, from, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "transferFrom failed"
        );
    }
}
