// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ISwapFeeModule, SwapFeeModuleData } from 'valantis-core/swap-fee-modules/interfaces/ISwapFeeModule.sol';
import { IVault } from './interfaces//IVault.sol';
import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';


/// @notice Dynamic swap fee module based on asset balances and virtual reserves in the vault.
contract FeeModule is ISwapFeeModule {
    IVault public vault;
    uint256 public constant BASE_FEE_BIPS = 3; // 0.03% base fee in bips

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
 
    // (tokenIn.balance / tokenOut.balance) - oraclePrice(tokenIn/tokenOut)
    // The fee amount is deduced from tokenOut.
    // Majority asset gives higher fees, and lower fees for minority asset.
    // Final fee is expressed in basis points 
    function _calculateDynamicFee(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal view returns (uint256) {
    }
}
