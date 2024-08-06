// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IVault} from "./interfaces/IVault.sol";

/// @notice Dynamically-shared-liquidity vault 
contract Vault is IVault {
    using SafeERC20 for IERC20;

    error Vault__addPool_invalidPool();
    error Vault__getReservesForPool_invalidPool();
    error Vault__getReservesForPool_invalidArrayLength();

    struct PoolState {
        address token0;
        address token1;
        uint256 reserve0;
        uint256 reserve1;
        bool isActive;
    }

    struct PoolShare {
        uint256 sharePercentage;
        uint256 lastRebalance;
    }


    mapping(address pool => PoolState) public pools;
    mapping(address pool => PoolShare) public poolShares;
    mapping(address asset => uint256 amount) public vaultBalances;
    mapping(address user => mapping(address asset => uint256 amount)) public userBalances;

    mapping(address => bool) private assetExists;
    address[] private uniqueAssets;

    function addPool(address _pool, address _token0, address _token1, uint256 _sharePercentage) external {
        if (pools[_pool].isActive) revert Vault__addPool_invalidPool();

        pools[_pool] = PoolState({token0: _token0, token1: _token1, reserve0: 0, reserve1: 0, isActive: true});

        _addAsset(_token0);
        _addAsset(_token1);

        setPoolShare(_pool, _sharePercentage);
    }

    function _addAsset(address asset) internal {
        if (!assetExists[asset]) {
            assetExists[asset] = true;
            uniqueAssets.push(asset);
        }
    }

    function deposit() {}

    function withdraw() {}

    function setPoolShare(address _pool, uint256 _percentage) public {
        // add a MAX_INITIAL_SHARE
    } 

    // Distribute liquidity across pools based on their shares
    function distributeLiquidity() {}

    // Adjust shares based on trading volume, utilization, etc
    // This would align the pools liquidity with what the market needs
    function adjustPoolShares() {}

    function getTotalLiquidity() {}

    function claimPoolManagerFees(uint256 _feePoolManager0, uint256 _feePoolManager1) external {}

    function getReservesForPool(address _pool, address[] calldata _tokens) external view returns (uint256[] memory) {
        if (!pools[_pool].isActive) revert Vault__getReservesForPool_invalidPool();
        if (_tokens.length != 2) revert Vault__getReservesForPool_invalidArrayLength();

        PoolState storage pool = pools[_pool];
        if (
            (_tokens[0] != pool.token0 && _tokens[0] != pool.token1)
                || (_tokens[1] != pool.token0 && _tokens[1] != pool.token1)
        ) {
            revert Vault__getReservesForPool_invalidPool();
        }
        uint256[] memory reserves = new uint256[](2);
        reserves[0] = _tokens[0] == pool.token0 ? pool.reserve0 : pool.reserve1;
        reserves[1] = _tokens[1] == pool.token1 ? pool.reserve1 : pool.reserve0;

        return reserves;
    }

    // Returns all unique assets managed by the vault
    // This might need to be adjusted to only a subset
    function getTokensForPool(address _pool) external view returns (address[] memory) {
        if (!pools[_pool].isActive) revert Vault__getReservesForPool_invalidPool();

        return uniqueAssets;
    }
}
