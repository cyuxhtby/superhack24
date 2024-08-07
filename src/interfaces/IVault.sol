// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.19;

import {ISovereignVaultMinimal} from "valantis-core/pools/interfaces/ISovereignVaultMinimal.sol";

interface IVault is ISovereignVaultMinimal {
    event PoolAdded(address indexed pool, address indexed token0, address indexed token1);
    event PoolRemoved(address indexed pool);
    event Deposit(address indexed user, uint256[] amounts, uint256 lpTokensMinted);
    event Withdraw(address indexed user, uint256 lpTokensBurned, uint256[] amounts);

    error Vault__TokensAndOraclesLengthMismatch();
    error Vault__PoolAlreadyExists();
    error Vault__TokenNotSupported();
    error Vault__PoolDoesNotExist();
    error Vault__IncorrectAmountsLength();
    error Vault__AmountMustBeGreaterThanZero();
    error Vault__InsufficientLPTokens();
    error Vault__InsufficientAssetBalance();
    error Vault__InvalidTokensLength();
    error Vault__InvalidOraclePrice();
}