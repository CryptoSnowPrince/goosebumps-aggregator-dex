// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

interface IFeeAggregator {
    function feeTokens() external view returns (address[] memory);
    function isFeeToken(address token) external view returns (bool);
    function calculateFee(uint256 amount) external view returns (uint256 fee, uint256 amountLeft);
    function calculateFee(address token, uint256 amount) external view returns (uint256 fee, uint256 amountLeft);

    function addFeeToken(address token) external;
    function addFeeTokens(address[] calldata tokens) external;
    function removeFeeToken(address token) external;
    function setGoosebumpsFee(uint256 fee) external;
}
