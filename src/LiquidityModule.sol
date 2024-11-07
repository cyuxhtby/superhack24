// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ISovereignALM } from "valantis-core/ALM/interfaces/ISovereignALM.sol";
import { ALMLiquidityQuoteInput, ALMLiquidityQuote } from "valantis-core/ALM/structs/SovereignALMStructs.sol";
import { IVault } from './interfaces/IVault.sol';

/// @notice Algorithmic Liquidity Module quoting constant product
contract LiquidityModule is ISovereignALM {
    IVault public vault;
    address public pool;

    constructor(address _vault, address _pool) {
        vault = IVault(_vault);
        pool = _pool;
    }
    
    function getLiquidityQuote(
        ALMLiquidityQuoteInput memory _almLiquidityQuoteInput,
        bytes memory /*_externalContext*/,
        bytes memory /*_verifierData*/
    ) external view override returns (ALMLiquidityQuote memory quote) {
        address[] memory tokens = vault.getTokensForPool(pool);
        uint256[] memory reserves = vault.getReservesForPool(pool, tokens);

        uint256 reserveIn = _almLiquidityQuoteInput.isZeroToOne ? reserves[0] : reserves[1];
        uint256 reserveOut = _almLiquidityQuoteInput.isZeroToOne ? reserves[1] : reserves[0];

        uint256 amountOut = (reserveOut * _almLiquidityQuoteInput.amountInMinusFee) / (reserveIn + _almLiquidityQuoteInput.amountInMinusFee);

        quote = ALMLiquidityQuote({
            isCallbackOnSwap: false, 
            amountOut: amountOut,
            amountInFilled: _almLiquidityQuoteInput.amountInMinusFee
        });

        return quote;
    }   

    function onDepositLiquidityCallback(uint256 _amount0, uint256 _amount1, bytes memory _data) external {}

    function onSwapCallback(bool _isZeroToOne, uint256 _amountIn, uint256 _amountOut) external {}
}