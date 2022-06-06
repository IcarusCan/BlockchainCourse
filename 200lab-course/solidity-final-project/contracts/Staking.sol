// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Reserve.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract Staking is Ownable {
    using Counters for Counters.Counter;
    StakingReserve public reserve;
    IERC20 public immutable gold;
    event StakeUpdate(
        address account,
        uint256 packageId,
        uint256 amount,
        uint256 totalProfit
    );
    event StakeReleased(
        address account,
        uint256 packageId,
        uint256 amount,
        uint256 totalProfit
    );
    struct StakePackage {
        uint256 rate;
        uint256 decimal;
        uint256 minStaking;
        uint256 lockTime;
        bool isOffline;
    }
    struct StakingInfo {
        uint256 startTime;
        uint256 timePoint;
        uint256 amount;
        uint256 totalProfit;
    }
    Counters.Counter private _stakePackageCount;
    mapping(uint256 => StakePackage) public stakePackages;
    mapping(address => mapping(uint256 => StakingInfo)) public stakes;

    /**
     * @dev Initialize
     * @notice This is the initialize function, run on deploy event
     * @param tokenAddr_ address of main token
     */
    constructor(address tokenAddr_) {
        gold = IERC20(tokenAddr_);
    }

    function setReserve(address reserveAddress_) public onlyOwner {
        require(
            reserveAddress_ != address(0),
            "Staking: Invalid reserve address"
        );
        reserve = StakingReserve(reserveAddress_);
    }

    /**
     * @dev Add new staking package
     * @notice New package will be added with an id
     */
    function addStakePackage(
        uint256 rate_,
        uint256 decimal_,
        uint256 minStaking_,
        uint256 lockTime_
    ) public onlyOwner {
        require(rate_ > 0, "Staking: Invalid rate");
        require(minStaking_ > 0, "Staking: Invalid minStaking_ amount");
        require(lockTime_ > 0, "Staking: Invalid lockTime_");

        _stakePackageCount.increment(); //ID start with 1
        uint256 packageId_ = _stakePackageCount.current(); // ID = 1
        stakePackages[packageId_] = StakePackage(
            rate_,
            decimal_,
            minStaking_,
            lockTime_,
            false
        );
    }

    /**
     * @dev Remove an stake package
     * @notice A stake package with packageId will be set to offline
     * so none of new staker can stake to an offine stake package
     */
    function removeStakePackage(uint256 packageId_) public onlyOwner {
        StakePackage storage _stakePackage = stakePackages[packageId_];
        require(
            _stakePackage.minStaking > 0,
            "Staking: Stake package non-existence"
        );
        require(
            _stakePackage.isOffline == false,
            "Staking: Package is offline"
        );

        _stakePackage.isOffline = true;
    }

    /**
     * @dev User stake amount of gold to stakes[address][packageId]
     * @notice if is there any amount of gold left in the stake package,
     * calculate the profit and add it to total Profit,
     * otherwise just add completely new stake.
     */
    function stake(uint256 amount_, uint256 packageId_) external {
        StakePackage memory _stakePackage = stakePackages[packageId_];
        require(packageId_ > 0, "Staking: Stake package non-existence");
        require(_stakePackage.isOffline == false, "Staking: Package is offline");
        require(amount_ > _stakePackage.minStaking, "Staking: stake amount must be greater than min stake");
        
        StakingInfo storage _stakingInfo = stakes[_msgSender()][packageId_];
        gold.transferFrom(_msgSender(), address(reserve), amount_);
        if (_stakingInfo.amount > 0) {
            uint256 _totalProfit = calculateProfit(packageId_);
            _stakingInfo.amount += amount_;
            _stakingInfo.timePoint = block.timestamp;
            _stakingInfo.totalProfit = _totalProfit;
        } else {
            _stakingInfo.amount = amount_;
            _stakingInfo.startTime = block.timestamp;
            _stakingInfo.timePoint = block.timestamp;
            _stakingInfo.totalProfit = 0;
        }

        emit StakeUpdate(_msgSender(), packageId_, _stakingInfo.amount, _stakingInfo.totalProfit);
    }

    /**
     * @dev Take out all the stake amount and profit of account's stake from reserve contract
     */
    function unStake(uint256 packageId_) external {
        // validate available package and approved amount
        StakePackage memory _stakePackage = stakePackages[packageId_];
        StakingInfo memory _stakingInfo = stakes[_msgSender()][packageId_];

        require(packageId_ > 0, "Staking: Invalid stake");
        require(
            (block.timestamp - _stakingInfo.timePoint) >= _stakePackage.lockTime,
            "Staking: lockTime is not enough"
        );
        uint256 _profit = calculateProfit(packageId_);
        uint256 _stakeAmount = _stakingInfo.amount;
        _stakingInfo.amount = 0;
        _stakingInfo.startTime = 0;
        _stakingInfo.timePoint = 0;
        _stakingInfo.totalProfit = 0;
        reserve.distributeGold(_msgSender(), _stakeAmount + _profit);

        emit StakeReleased(_msgSender(), packageId_, _stakeAmount, _profit);
    }

    /**
     * @dev calculate current profit of an package of user known packageId
     */

    function calculateProfit(uint256 packageId_) public view returns (uint256) {
        StakePackage memory _stakePackage = stakePackages[packageId_];
        StakingInfo memory _stakingInfo = stakes[_msgSender()][packageId_];
        uint256 _stakeTime = block.timestamp - _stakingInfo.timePoint;
        uint256 _profit = (_stakeTime*_stakingInfo.amount*getAprOfPackage(packageId_)) / 10**_stakePackage.decimal;

        return _stakingInfo.totalProfit + _profit;
    }

    function getAprOfPackage(uint256 packageId_) public view returns (uint256) {
        StakePackage memory _stakePackage = stakePackages[packageId_];
        return _stakePackage.rate;
    }
}
