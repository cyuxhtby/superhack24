// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ISwapFeeModule, SwapFeeModuleData } from 'valantis-core/swap-fee-modules/interfaces/ISwapFeeModule.sol';
import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import { IVault } from './interfaces//IVault.sol';

/// @notice Dynamic swap fee module based on asset balances and market weighted reserves in the vault.
contract FeeModule is ISwapFeeModule {
    IVault public vault;
    uint256 public constant BASE_FEE_BIPS = 10; // 0.1%
    uint256 public constant FEE_COEFFICIENT_BIPS = 3; // 0.03%
    uint256 constant PRECISION = 1e18;

    constructor(address _vault) {
        vault = IVault(_vault);
    }

    function getSwapFeeInBips(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        address sender,
        bytes calldata swapFeeModuleContext
    ) external override returns (SwapFeeModuleData memory) {
        uint256 feeInBips = _calculateDynamicFee(tokenIn, tokenOut, amountIn);
        return SwapFeeModuleData({
            feeInBips: feeInBips,
            internalContext: new bytes(0)
        });
    }

    // N/A
    function callbackOnSwapEnd(
        uint256 _effectiveFee,
        int24 _spotPriceTick,
        uint256 _amountInUsed,
        uint256 _amountOut,
        SwapFeeModuleData memory _swapFeeModuleData
    ) external override {}

    function callbackOnSwapEnd(
        uint256 _effectiveFee,
        uint256 _amountInUsed,
        uint256 _amountOut,
        SwapFeeModuleData memory _swapFeeModuleData
    ) external override {
        if (_effectiveFee == 0) return;

        address pool = msg.sender;

        address token0 = vault.getTokensForPool(pool)[0];
        address token1 = vault.getTokensForPool(pool)[1];

        address[] memory tokens = new address[](2);
        uint256 reserveIn;
        uint256 reserveOut;

        if (_amountInUsed > _amountOut) {
            // Assume token0 is tokenIn, token1 is tokenOut
            reserveIn = vault.getMarketWeightedReserve(token0);
            reserveOut = vault.getMarketWeightedReserve(token1);
        } else {
            // Assume token1 is tokenIn, token0 is tokenOut
            reserveIn = vault.getMarketWeightedReserve(token1);
            reserveOut = vault.getMarketWeightedReserve(token0);
        }

        uint256 feeValue = (reserveOut * _effectiveFee) / reserveIn;

        // Mint LP tokens based on the fee value
        uint256 totalSupplyCache = vault.totalSupply();
        uint256 lpTokensMinted = (totalSupplyCache == 0) ? feeValue : (feeValue * totalSupplyCache) / vault.getTotalValue();

        address recipient = address(this); // placeholder for erc4626 
        vault.mintLPTokens(lpTokensMinted, recipient); // this function does not exist rn
    }
 
    // Calculates dynamic fee from market-weighted reserves and ensures it's not below the base fee.
    // Majority asset gives higher fees, and lower fees for minority asset.
    function _calculateDynamicFee(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal view returns (uint256) {
        address pool = msg.sender;
        address[] memory tokens = new address[](2);
        tokens[0] = tokenIn;
        tokens[1] = tokenOut;
        uint256[] memory reserves = vault.getReservesForPool(pool, tokens);
        uint256 reserveIn = reserves[0];
        uint256 reserveOut = reserves[1];

        uint256 balanceRatio = (reserveIn * PRECISION) / reserveOut; 
        uint256 feeInBips = BASE_FEE_BIPS + (FEE_COEFFICIENT_BIPS * (balanceRatio - PRECISION)) / PRECISION;

        if (feeInBips < BASE_FEE_BIPS) {
            feeInBips = BASE_FEE_BIPS;
        }

        return feeInBips;
    }
}
