// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

interface IGoosebumpsRouterPairs {
    function feeAggregator() external returns (address);

    function pairFor(address factory, address tokenA, address tokenB) external view returns (address pair);
    function getReserves(address factory, address tokenA, address tokenB) 
        external view returns (uint256 reserveA, uint256 reserveB);
    function getAmountOut(address factory, uint256 amountIn, 
        uint256 reserveIn, uint256 reserveOut) 
        external view returns (uint256 amountOut, uint256 fee);
    function getAmountOut(address factory, bool feePayed, uint256 amountIn, 
        uint256 reserveIn, uint256 reserveOut)
        external view returns (uint256 amountOut, uint256 fee);
    function getAmountIn(address factory, uint256 amountOut, 
        uint256 reserveIn, uint256 reserveOut) 
        external view returns (uint256 amountIn, uint256 fee);
    function getAmountIn(address factory, bool feePayed, uint256 amountOut, 
        uint256 reserveIn, uint256 reserveOut) 
        external view returns (uint256 amountIn, uint256 fee);
    function getAmountsOut(address[] calldata _factories, uint256 amountIn, address[] calldata path) 
        external view returns (uint256[] memory amounts, uint256 feePayed);
    function getAmountsIn(address[] calldata _factories, uint256 amountOut, address[] calldata path) 
        external view returns (uint256[] memory amounts, uint256 feePayed);

    function setFeeAggregator(address aggregator) external;
    function setFactory(address _factory, bytes32 initHash) external;
    function removeFactory(address _factory) external;
    function hasFactory(address _factory) external view returns (bool);
    function allFactories() external view returns (address[] memory);
    function setLPFee(address _factory, uint256 fee) external;
}
