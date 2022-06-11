pragma solidity = 0.8.14;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/ILiquidityGaugeV3.sol";
import "../interfaces/IIdleCDO.sol";
import "../interfaces/IStakeManager.sol";
import "../interfaces/IDistributorProxy.sol";

contract StakeStEthTranchesManager is IStakeManager , Ownable {
  using SafeERC20 for IERC20;

  ILiquidityGaugeV3 private immutable Gauge;
  IERC20 private immutable UnderlingToken;
  IERC20 private immutable RewardsToken;
  IIdleCDO private immutable Tranche;
  IDistributorProxy private constant DistributorProxy = IDistributorProxy(0x074306BC6a6Fc1bD02B425dd41D742ADf36Ca9C6);

  constructor (address _gauge, address _underlingToken, address _rewardsToken, address _tranche) {
    require(_gauge != address(0), "Gauge cannot be 0 address");
    require(_underlingToken != address(0), "UnderlingToken cannot be 0 address");
    require(_tranche != address(0), "Tranche cannot be 0 address");
    Gauge = ILiquidityGaugeV3(_gauge);
    UnderlingToken = IERC20(_underlingToken);
    Tranche = IIdleCDO(_tranche);
    RewardsToken = IERC20(_rewardsToken);
  }

  function claimStaked() external onlyOwner {
    _claimStaked();
  }
  
  function _claimStaked() internal {
    uint256 balance = Gauge.balanceOf(msg.sender);
    if (balance == 0) {
      return;
    }
    IERC20(address(Gauge)).safeTransferFrom(msg.sender, address(this), balance);
    
    address sender = msg.sender;
    _claimIdle(sender);
    _withdrawAndClaimGauge();
    _withdrawTranchee();
    _transferRewardsTokens();
    _transferUnderlingToken(sender);
  }

  
  function _claimIdle(address _from) internal {
    DistributorProxy.distribute_for(address(Gauge), _from);
  }

  function _withdrawAndClaimGauge() internal {
    uint256 gaugeBalance  = Gauge.balanceOf(address(this));
    Gauge.withdraw(gaugeBalance, false);
  }

  function _withdrawTranchee() internal{
    address _trancheAA = Tranche.AATranche();
    uint256 _trancheAABalance = IERC20(_trancheAA).balanceOf(address(this));
    Tranche.withdrawAA(_trancheAABalance);
  }

  function _transferRewardsTokens() internal {
    uint256 _rewardsTokenBalance = RewardsToken.balanceOf(address(this));
    RewardsToken.safeTransfer(msg.sender, _rewardsTokenBalance);
  }

  function _transferUnderlingToken(address _to) internal {
    uint256 _underlingTokenBalance = UnderlingToken.balanceOf(address(this));
    UnderlingToken.safeTransfer(_to, _underlingTokenBalance);
  }

  function token() external view returns (address) {
    return address(UnderlingToken);
  }
  
  function stakedToken() external view returns (address){
    return address(Gauge);
  }

}