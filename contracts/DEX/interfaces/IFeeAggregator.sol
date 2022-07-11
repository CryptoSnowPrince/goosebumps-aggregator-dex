// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

interface IFeeAggregator {
    function feeTokens() external view returns (address[] memory);
    function isFeeToken(address token) external view returns (bool);
    function calculateFee(uint256 amount) external view returns (uint256 fee, uint256 amountLeft);
    function calculateFee(address token, uint256 amount) external view returns (uint256 fee, uint256 amountLeft);

    function addFeeToken(address token) external;
    function addFeeTokens(address[] calldata tokens) external;
    function approveFeeToken(address token) external;
    function approveFeeTokens() external;
    function removeFeeToken(address token) external;
    function setDPexFee(uint256 fee) external;
    function setPSIAddress(address _psi) external;
    function addTokenFee(address token, uint256 fee) external;
    function addTokenFees(address[] memory tokens, uint256[] memory fees) external;
    function reflectFees(uint256 deadline) external;
    function reflectFee(address token, uint256 deadline) external;
}
