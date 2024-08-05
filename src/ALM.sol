// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ISovereignALM } from "valantis-core/ALM/interfaces/ISovereignALM.sol";
import { ALMLiquidityQuoteInput, ALMLiquidityQuote } from "valantis-core/ALM/structs/SovereignALMStructs.sol";


contract ALM is ISovereignALM {
    
    function getLiquidityQuote(
        ALMLiquidityQuoteInput memory _almLiquidityQuoteInput,
        bytes memory /*_externalContext*/,
        bytes memory /*_verifierData*/
    ) external returns (ALMLiquidityQuote memory quote) {}

    function onDepositLiquidityCallback(uint256 _amount0, uint256 _amount1, bytes memory _data) external {}

    function onSwapCallback(bool _isZeroToOne, uint256 _amountIn, uint256 _amountOut) external {}
}