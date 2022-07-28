// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

interface IFeeAggregator {
    function calculateFeeAndAmountOut(uint256 amountIn) external view returns (uint256 fee, uint256 amountOut);
    function calculateFeeAndAmountIn(uint256 amountOut) external view returns (uint256 fee, uint256 amountIn);
    function setGoosebumpsFee(uint256 fee) external;
}
