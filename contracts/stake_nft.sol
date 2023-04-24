// SPDX-License-Identifier: UNLICENSED
//

pragma solidity =0.8.17;

import "./interfaces/IIotabeeSwapNFT.sol";
import "./ownable.sol";

contract StakeLiquidity is Ownable {
    /// @dev Division constant
    uint32 public constant divConst = 1000000;
    /// @dev The minimum tick that may be passed to #getSqrtRatioAtTick computed from log base 1.0001 of 2**-128
    int24 internal constant MIN_TICK = -887272;
    /// @dev The maximum tick that may be passed to #getSqrtRatioAtTick computed from log base 1.0001 of 2**128
    int24 internal constant MAX_TICK = -MIN_TICK;

    // nft token address for swap of v3
    IIotabeeSwapNFT public immutable nftToken;
    // token0, token1 are the pair of pool, token0 < token1
    address public immutable token0;
    address public immutable token1;
    // token address, to set by the owner
    address public immutable rewardToken;

    struct StakingNFT {
        address owner; // owner of NFT
        uint256 score; // score of the amount
        uint256 beginNo; // as week number, contained
        uint256 endNo; // as week number, not contained
    }
    // all the NFTs, tokenId => stakingNFT
    mapping(uint256 => StakingNFT) public stakingNFTs;
    // user address => tokenIds of NFT
    mapping(address => uint256[]) public userNFTs;
    // tokenId => week number => reward is claimed or not
    mapping(uint256 => mapping(uint256 => bool)) public bClaimReward;
    // weekNumber => score
    mapping(uint256 => uint256) totalScores;
    // the owner to set, week number => reward token amount
    mapping(uint256 => uint256) public rewardsOf;

    event Stake(address indexed user, uint256 tokenId, uint256 amount, uint8 k);
    event Withdraw(address indexed user, uint256 tokenId);
    event ClaimReward(address indexed user, uint256 tokenId, uint256 amount);
    event SetReward(address indexed user, uint256 no, uint256 amount);

    uint8 public MAX_WEEKS;
    uint256 public MAX_SCALE;

    constructor(
        address tokenA,
        address tokenB,
        address nft,
        address _rewardToken
    ) {
        owner = msg.sender;
        (token0, token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        nftToken = IIotabeeSwapNFT(nft);
        rewardToken = _rewardToken;

        MAX_WEEKS = 52;
        MAX_SCALE = 2;
    }

    function stake(uint256 tokenId, uint8 k) external {
        require(k > 0 && k <= MAX_WEEKS, "stake weeks error");
        uint256 liquidity = _deposit(tokenId);
        uint256 weekNumber = block.timestamp / 604800 + 1;
        uint256 score = getScore(liquidity, k);

        for (uint8 i = 0; i < k; i++) {
            totalScores[weekNumber + i] += score;
        }

        stakingNFTs[tokenId] = StakingNFT(
            msg.sender,
            score,
            weekNumber,
            weekNumber + k
        );
        userNFTs[msg.sender].push(tokenId);
        emit Stake(msg.sender, tokenId, liquidity, k);
    }

    function withdraw(uint256 tokenId) external {
        require(stakingNFTs[tokenId].owner == msg.sender, "owner forbidden");
        uint256 weekNumber = block.timestamp / 604800;
        require(stakingNFTs[tokenId].endNo <= weekNumber, "locked time");
        uint256[] storage ids = userNFTs[msg.sender];
        for (uint256 i = 0; i < ids.length; i++) {
            if (tokenId == ids[i]) {
                ids[i] = ids[ids.length - 1];
                ids.pop();
                nftToken.safeTransferFrom(address(this), msg.sender, tokenId);
                break;
            }
        }
        emit Withdraw(msg.sender, tokenId);
    }

    function claimReward(uint256 tokenId, uint256[] memory Nos) external {
        require(stakingNFTs[tokenId].owner == msg.sender, "owner forbidden");
        uint256 total = 0;
        for (uint256 i = 0; i < Nos.length; i++) {
            uint256 no = Nos[i];
            if (bClaimReward[tokenId][no]) {
                continue;
            }
            if (
                no >= stakingNFTs[tokenId].endNo ||
                no < stakingNFTs[tokenId].beginNo
            ) {
                continue;
            }
            bClaimReward[tokenId][no] = true;
            total +=
                (rewardsOf[no] * stakingNFTs[tokenId].score) /
                totalScores[no];
        }
        _safeTransfer(rewardToken, msg.sender, total);
        emit ClaimReward(msg.sender, tokenId, total);
    }

    function setReward(uint256 no, uint256 amount) external {
        require(msg.sender == owner, "forbidden");
        _safeTransferFrom(rewardToken, msg.sender, address(this), amount);
        rewardsOf[no] += amount;

        emit SetReward(msg.sender, no, amount);
    }

    function getUserNFTs() external view returns (uint256[] memory, uint256) {
        uint256[] memory ids = new uint256[](userNFTs[msg.sender].length);
        uint256 weekNumber = block.timestamp / 604800;
        uint256 front = 0;
        uint256 end = userNFTs[msg.sender].length;
        for (uint256 i = 0; i < userNFTs[msg.sender].length; i++) {
            uint256 tokenId = userNFTs[msg.sender][i];
            if (stakingNFTs[tokenId].endNo > weekNumber) {
                ids[front] = tokenId;
                front++;
            } else {
                end--;
                ids[end] = tokenId;
            }
        }
        return (ids, end);
    }

    function getUnclaimed(
        uint256 tokenId
    ) external view returns (uint256 begin, uint256 end, uint256 unclaimed) {
        begin = stakingNFTs[tokenId].beginNo;
        end = stakingNFTs[tokenId].endNo;
        for (uint256 no = begin; no < end; no++) {
            if (!bClaimReward[tokenId][no]) {
                unclaimed = no;
            }
        }
    }

    /**
     * @dev get score based on amount and number of weeks staked
     * @param amount amount of liquidity tokens staked
     * @param k number of weeks staked
     * @return score
     */
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

    function _deposit(uint256 tokenId) internal returns (uint256) {
        (
            ,
            ,
            address t0,
            address t1,
            ,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            ,
            ,
            ,

        ) = nftToken.positions(tokenId);
        require((t0 == token0) && (t1 == token1), "lp pair error");
        require(
            (tickLower == MIN_TICK) && (tickUpper == MAX_TICK),
            "tick range error"
        );

        require(nftToken.getApproved(tokenId) == address(this), "not approve");
        nftToken.safeTransferFrom(msg.sender, address(this), tokenId);
        return liquidity;
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
        MAX_WEEKS = maxWeeks;
        MAX_SCALE = maxScale;
    }
}
