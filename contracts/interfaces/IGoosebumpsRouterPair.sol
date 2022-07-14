// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "./IGoosebumpsPair.sol";

interface IGoosebumpsRouterPair is IGoosebumpsPair {
    function swap(uint256 amount0Out, uint256 amount1Out, address to) external;
}