// SPDX-License-Identifier: UNLICENSED
//

pragma solidity =0.8.17;

import "./interfaces/IERC20.sol";
import "./ownable.sol";

contract StakeERC20Liquidity is Ownable {
    /// @dev Division constant
    uint32 public constant divConst = 1000000;

    // erc20 token address for swap of v2
    address public immutable lpToken;
    // token address, to set by the owner
    address public immutable rewardToken;

    struct StakingERC20 {
        uint256 amount; // lp token amount
        uint256 score; // score of the amount
        uint256 beginNo; // as week number, contained
        uint256 endNo; // as week number, not contained
        uint256 toClaimedNo;
    }
    uint256 public nonce;
    mapping(uint256 => StakingERC20) public stakingERC20s;
    // user address => StakingERC20s
    mapping(address => uint256[]) public userERC20s;
    // nonce => week number => reward is claimed or not
    mapping(uint256 => mapping(uint256 => bool)) public bClaimReward;
    // weekNumber => score
    mapping(uint256 => uint256) totalScores;
    // the owner to set, week number => reward token amount
    mapping(uint256 => uint256) public rewardsOf;
    uint256 public latestNo;

    event Stake(address indexed user, uint256 tokenId, uint256 amount, uint8 k);
    event Withdraw(address indexed user, uint256 tokenId);
    event ClaimReward(address indexed user, uint256 amount);
    event SetReward(address indexed user, uint256 no, uint256 amount);

    uint8 public MAX_WEEKS;
    uint256 public MAX_SCALE;
    uint24 public constant WEEK_SECONDS = 604800;

    constructor(address _lpToken, address _rewardToken) {
        owner = msg.sender;
        lpToken = _lpToken;
        rewardToken = _rewardToken;

        MAX_WEEKS = 52;
        MAX_SCALE = 2;
    }

    function stake(uint256 amount, uint8 k) external {
        require(k > 0 && k <= MAX_WEEKS, "k 1~52");
        _safeTransferFrom(lpToken, msg.sender, address(this), amount);
        uint256 weekNumber = block.timestamp / WEEK_SECONDS + 1;
        uint256 score = getScore(amount, k);

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

    function withdraw(uint256 amount) external {
        uint256 weekNumber = block.timestamp / WEEK_SECONDS;
        uint256 total = 0;
        for (uint256 i = userERC20s[msg.sender].length; i >= 0; i--) {
            uint id = userERC20s[msg.sender][i];
            if (stakingERC20s[id].endNo <= weekNumber) {
                total += stakingERC20s[id].amount;
                if (total <= amount) {
                    userERC20s[msg.sender][i] = userERC20s[msg.sender][
                        userERC20s[msg.sender].length
                    ];
                    userERC20s[msg.sender].pop();
                } else {
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
    }

    function claimReward() external {
        uint256 weekNumber = block.timestamp / WEEK_SECONDS;
        uint256 total = 0;
        for (uint256 i = 0; i < userERC20s[msg.sender].length; i++) {
            uint256 id = userERC20s[msg.sender][i];
            for (
                uint256 no = stakingERC20s[id].toClaimedNo;
                no < stakingERC20s[id].endNo;
                no++
            ) {
                if (
                    bClaimReward[id][no] ||
                    no > weekNumber ||
                    rewardsOf[no] == 0
                ) {
                    continue;
                }
                bClaimReward[id][no] = true;
                stakingERC20s[id].toClaimedNo = no + 1;
                total +=
                    (rewardsOf[no] * stakingERC20s[id].score) /
                    totalScores[no];
            }
        }
        _safeTransfer(rewardToken, msg.sender, total);
        emit ClaimReward(msg.sender, total);
    }

    function setReward(uint256 no, uint256 amount) external {
        require(msg.sender == owner, "forbidden");
        _safeTransferFrom(rewardToken, msg.sender, address(this), amount);
        rewardsOf[no] += amount;

        emit SetReward(msg.sender, no, amount);
    }

    function getStaking() external view returns (uint256, uint256) {
        uint256 weekNumber = block.timestamp / WEEK_SECONDS;
        uint256 total = 0;
        uint256 staking = 0;
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

    // * @dev get score based on amount and number of weeks staked
    // * @param amount amount of liquidity tokens staked
    // * @param k number of weeks staked
    // * @return score

    function getScore(uint256 amount, uint8 k) public view returns (uint256) {
        // Y = MX + B
        // Y = Multiplier
        // M = 1 / (52-1)
        // X = weeks staked/locked
        // B = 2 - M * 52
        //uint256 precision = 10e18;
        //uint256 m = (precision / (52 - 1));
        //uint256 b = 2 * precision - 52 * m;
        //uint256 score = (amount * (m * numPeriods + b)) / precision;
        uint256 score = (amount * ((MAX_SCALE - 1) * k + MAX_WEEKS)) /
            MAX_WEEKS;
        return score;
    }

    function _safeTransfer(address token, address to, uint256 value) private {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0xa9059cbb, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "TRANSFER_FAILED"
        );
    }

    function _safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) private {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(0x23b872dd, from, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "transferFrom failed"
        );
    }

    function setScoreFormula(uint8 maxWeeks, uint256 maxScale) external {
        require(msg.sender == owner, "forbidden");
        require(maxScale > 1, "maxScale too small");
        MAX_WEEKS = maxWeeks;
        MAX_SCALE = maxScale;
    }
}
