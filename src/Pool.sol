// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {SovereignPool} from "valantis-core/pools/SovereignPool.sol";
import {SovereignPoolConstructorArgs} from "valantis-core/pools/structs/SovereignPoolStructs.sol";

contract Pool is SovereignPool {

    constructor(SovereignPoolConstructorArgs memory args) SovereignPool(args) {}

}