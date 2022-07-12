// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

interface IGoosebumpsRouterPair is IGoosebumpsPair {
    function swap(uint amount0Out, uint amount1Out, address to) external;
}