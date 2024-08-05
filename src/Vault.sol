// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IVault} from "./interfaces/IVault.sol";

contract Vault is IVault {

    function claimPoolManagerFees(uint256 _feePoolManager0, uint256 _feePoolManager1) external {}

    function getReservesForPool(address _pool, address[] calldata _tokens) external view returns (uint256[] memory) {}

    function getTokensForPool(address _pool) external view returns (address[] memory) {}

}