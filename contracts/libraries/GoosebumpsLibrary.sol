// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import '../interfaces/IGoosebumpsPair.sol';
import '../interfaces/IFeeAggregator.sol';

library GoosebumpsLibrary {
    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'GoosebumpsLibrary: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'GoosebumpsLibrary: ZERO_ADDRESS');
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) internal pure returns (uint256 amountB) {
        require(amountA > 0, 'GoosebumpsLibrary: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'GoosebumpsLibrary: INSUFFICIENT_LIQUIDITY');
        amountB = amountA * reserveB / reserveA;
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address factory, bytes32 initPairHash, address tokenA, address tokenB) 
        internal pure returns (address pair) 
    {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(uint160(uint256(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                initPairHash
            )))));
    }

    // fetches and sorts the reserves for a pair
    function getReserves(address factory, bytes32 initPairHash, address tokenA, address tokenB) internal view returns (uint256 reserveA, uint256 reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint256 reserve0, uint256 reserve1,) = IGoosebumpsPair(pairFor(factory, initPairHash, tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut, uint256 lpFee) 
        internal pure returns (uint256 amountOut)
    {
        require(amountIn > 0, 'GoosebumpsLibrary: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'GoosebumpsLibrary: INSUFFICIENT_LIQUIDITY');
        amountIn = amountIn * (10000 - lpFee);
        uint256 numerator = amountIn * reserveOut;
        uint256 denominator = reserveIn * 10000 + amountIn;
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(uint256 amountOut, uint256 reserveIn, uint256 reserveOut, uint256 lpFee) 
        internal pure returns (uint256 amountIn)
    {
        require(amountOut > 0, 'GoosebumpsLibrary: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'GoosebumpsLibrary: INSUFFICIENT_LIQUIDITY');
        uint256 numerator = reserveIn * amountOut * 10000;
        uint256 denominator = (reserveOut - amountOut) * (10000 - lpFee);
        amountIn = numerator / denominator + 1;
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(
        address feeAggregator,
        address[] memory factories,
        bytes32[] memory initPairHashes,
        uint256 amountIn,
        address[] memory path,
        uint256[] memory lpFees
    ) internal view returns (uint256[] memory amounts, uint256 feeAmount) {
        require(path.length >= 2, 'GoosebumpsLibrary: INVALID_PATH');
        amounts = new uint256[](path.length);
        (feeAmount, amounts[0]) = IFeeAggregator(feeAggregator).calculateFeeAndAmountOut(amountIn);
        for (uint256 i = 0; i < path.length - 1; i++) {
            (uint256 reserveIn, uint256 reserveOut) = 
                getReserves(factories[i], initPairHashes[i], path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut, lpFees[i]);
        }
    }

    /**
     * Note performs chained getAmountIn calculations on any number of pairs.
     *      totalAmountIn = amounts[0] + feeAmount
     */
    function getAmountsIn(
        address feeAggregator,
        address[] memory factories,
        bytes32[] memory initPairHashes,
        uint256 amountOut,
        address[] memory path,
        uint256[] memory lpFees
    ) internal view returns (uint256[] memory amounts, uint256 feeAmount) {
        require(path.length >= 2, 'GoosebumpsLibrary: INVALID_PATH');
        amounts = new uint256[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint256 i = path.length - 1; i > 0; i--) {
            (uint256 reserveIn, uint256 reserveOut) = 
                getReserves(factories[i - 1], initPairHashes[i - 1], path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut, lpFees[i - 1]);
        }
        (feeAmount,) = IFeeAggregator(feeAggregator).calculateFeeAndAmountIn(amounts[0]);
    }
}
