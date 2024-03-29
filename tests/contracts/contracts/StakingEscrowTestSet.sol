// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.0;


import "contracts/StakingEscrow.sol";
import "contracts/NuCypherToken.sol";
import "threshold/IStaking.sol";

/**
* @notice Enhanced version of StakingEscrow to use in tests
*/
contract EnhancedStakingEscrow is StakingEscrow {

    constructor(
        NuCypherToken _token,
        WorkLockInterface _workLock,
        IStaking _tStaking
    )
        StakingEscrow(
            _token,
            _workLock,
            _tStaking
        )
    {
    }

    function setStaker(address _staker, uint256 _value, uint16 _lastCommittedPeriod) external {
        StakerInfo storage info = stakerInfo[_staker];
        info.value = _value;
        info.lastCommittedPeriod = _lastCommittedPeriod;
        stakers.push(_staker);
    }

}


/**
* @notice Upgrade to this contract must lead to fail
*/
contract StakingEscrowBad is StakingEscrow {

    constructor(
        NuCypherToken _token,
        WorkLockInterface _workLock,
        IStaking _tStaking
    )
        StakingEscrow(
            _token,
            _workLock,
            _tStaking
        )
    {
    }

    function getStakersLength() external override view returns (uint256) {}

}


/**
* @notice Contract for testing upgrading the StakingEscrow contract
*/
contract StakingEscrowV2Mock is StakingEscrow {

    uint256 public valueToCheck;

    constructor(
        NuCypherToken _token,
        WorkLockInterface _workLock,
        IStaking _tStaking
    )
        StakingEscrow(
            _token,
            _workLock,
            _tStaking
        )
    {
        valueToCheck = 2;
    }

    function setValueToCheck(uint256 _valueToCheck) public {
        valueToCheck = _valueToCheck;
    }

    function verifyState(address _testTarget) public override {
        super.verifyState(_testTarget);
        require(delegateGet(_testTarget, this.valueToCheck.selector) == valueToCheck);
    }

    function finishUpgrade(address _target) public override onlyWhileUpgrading {
        StakingEscrowV2Mock escrow = StakingEscrowV2Mock(_target);
        valueToCheck = escrow.valueToCheck();
        emit UpgradeFinished(_target, msg.sender);
    }
}


/**
* @notice Contract for testing staking escrow contract
*/
contract WorkLockForStakingEscrowMock {

    NuCypherToken public immutable token;
    StakingEscrow public escrow;

    constructor(NuCypherToken _token) {
        token = _token;
    }

    function setStakingEscrow(StakingEscrow _escrow) external {
        escrow = _escrow;
    }

    function setWorkMeasurement(address _staker, bool _measureWork) external returns (uint256) {
        return escrow.setWorkMeasurement(_staker, _measureWork);
    }

    function depositFromWorkLock(address _staker, uint256 _value, uint16 _periods) external {
        token.approve(address(escrow), _value);
        escrow.depositFromWorkLock(_staker, _value, _periods);
    }
}


/**
* @notice Contract for testing staking escrow contract
*/
contract ThresholdStakingForStakingEscrowMock {

    StakingEscrow public escrow;

    struct StakingProviderInfo {
        uint256 staked;
        uint96 minStaked;
    }

    mapping(address => StakingProviderInfo) public stakingProviders;

    function setStakingEscrow(StakingEscrow _escrow) external {
        escrow = _escrow;
    }

    function stakedNu(address _stakingProvider) external view returns (uint256) {
        return stakingProviders[_stakingProvider].staked;
    }

    function getMinStaked(address _stakingProvider, IStaking.StakeType _stakeTypes) external view returns (uint96) {
        require(_stakeTypes == IStaking.StakeType.NU);
        return stakingProviders[_stakingProvider].minStaked;
    }

    function stakes(address _stakingProvider) external view returns
    (
        uint96 tStake,
        uint96 keepInTStake,
        uint96 nuInTStake
    ) {
        tStake = 0;
        keepInTStake = 0;
        nuInTStake = uint96(stakingProviders[_stakingProvider].staked);
    }

    function slashStaker(
        address _staker,
        uint256 _penalty,
        address _investigator,
        uint256 _reward
    )
        external
    {
        escrow.slashStaker(_staker, _penalty, _investigator, _reward);
    }

    function requestMerge(address _staker, address _stakingProvider) external {
        stakingProviders[_stakingProvider].staked = escrow.requestMerge(_staker, _stakingProvider);
    }

    function setStakedNu(address _stakingProvider, uint256 _staked) external {
        require(_staked <= stakingProviders[_stakingProvider].staked);
        stakingProviders[_stakingProvider].staked = _staked;
    }

    function setMinStaked(address _stakingProvider, uint96 _minStaked) external {
        require(_minStaked <= stakingProviders[_stakingProvider].staked);
        stakingProviders[_stakingProvider].minStaked = _minStaked;
    }
}
