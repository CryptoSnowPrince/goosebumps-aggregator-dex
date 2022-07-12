// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import './libraries/GoosebumpsLibrary.sol';
import './libraries/OrderedEnumerableMap.sol';
import './interfaces/IGoosebumpsRouterPairs.sol';
import './utils/Ownable.sol';

contract GoosebumpsRouterPairs is IGoosebumpsRouterPairs, Ownable {
    using OrderedEnumerableMap for OrderedEnumerableMap.AddressToBytes32Map;

    address public override feeAggregator;

    OrderedEnumerableMap.AddressToBytes32Map private factories;
    mapping(address => uint256) public lpFees;

    modifier validFactory(address factory) {
        require(hasFactory(factory), 'GoosebumpsRouterPairs: INVALID_FACTORY');
        _;
    }

    constructor(address _aggregator) {
        feeAggregator = _aggregator;
    }

    // **** LIBRARY FUNCTIONS ****
    function pairFor(address factory, address tokenA, address tokenB) external view override returns (address pair) 
    {
        return GoosebumpsLibrary.pairFor(factory, getInitHash(factory), tokenA, tokenB);
    }
    function getReserves(address factory, address tokenA, address tokenB) 
        external view override returns (uint256 reserveA, uint256 reserveB)
    {
        return GoosebumpsLibrary.getReserves(factory, getInitHash(factory), tokenA, tokenB);
    }
    function getAmountOut(address factory, address tokenIn, uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        external view override returns (uint256 amountOut, uint256 fee)
    {
        return GoosebumpsLibrary.getAmountOut(feeAggregator, tokenIn, false, amountIn, reserveIn, reserveOut, getLPFee(factory));
    }
    function getAmountOut(
        address factory,
        address tokenIn,
        bool feePayed,
        uint256 amountIn, 
        uint256 reserveIn,
        uint256 reserveOut
    ) external view override returns (uint256 amountOut, uint256 fee)
    {
        return GoosebumpsLibrary.getAmountOut(feeAggregator, tokenIn, feePayed, amountIn, reserveIn, reserveOut, getLPFee(factory));
    }
    function getAmountIn(address factory, address tokenOut, uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        external view override returns (uint256 amountIn, uint256 fee) 
    {
        return GoosebumpsLibrary.getAmountIn(feeAggregator, tokenOut, false, amountOut, reserveIn, reserveOut, getLPFee(factory));
    }
    function getAmountIn(
        address factory,
        address tokenOut,
        bool feePayed,
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) external view override returns (uint256 amountIn, uint256 fee) 
    {
        return GoosebumpsLibrary.getAmountIn(feeAggregator, tokenOut, feePayed, amountOut, reserveIn, reserveOut, getLPFee(factory));
    }
    function getAmountsOut(address[] calldata _factories, uint256 amountIn, address[] calldata path)
        external view override returns (uint256[] memory amounts, uint256 feeAmount, address feeToken) 
    {
        (bytes32[] memory hashes, uint256[] memory fees) = getInitHashesAndFees(_factories);
        return GoosebumpsLibrary.getAmountsOut(feeAggregator, _factories, hashes, amountIn, path, fees);
    }
    function getAmountsIn(address[] calldata _factories, uint256 amountOut, address[] calldata path)
        external view override returns (uint256[] memory amounts, uint256 feeAmount, address feeToken) 
    {
        (bytes32[] memory hashes, uint256[] memory fees) = getInitHashesAndFees(_factories);
        return GoosebumpsLibrary.getAmountsIn(feeAggregator, _factories, hashes, amountOut, path, fees);
    }

    function getInitHashesAndFees(address[] memory _factories) internal view 
        returns (bytes32[] memory, uint256[] memory) 
    {
        bytes32[] memory hashes = new bytes32[](_factories.length);
        uint256[] memory fees = new uint256[](_factories.length);
        for(uint256 idx = 0; idx < _factories.length; idx++) {
            hashes[idx] = getInitHash(_factories[idx]);
            fees[idx] = getLPFee(_factories[idx]);
        }
        return (hashes, fees);
    }
    function getInitHash(address factory) validFactory(factory) internal view returns (bytes32) 
    {
        return factories.get(factory);
    }
    function getLPFee(address factory) validFactory(factory) internal view returns (uint256) 
    {
        return lpFees[factory];
    }
    
    /** Router internal modifiers */
    function setFeeAggregator(address aggregator) external override onlyOwner {
        require(aggregator != address(0), "GoosebumpsRouterPairs: FEE_AGGREGATOR_NO_ADDRESS");
        feeAggregator = aggregator;
    }
    function setFactory(address _factory, bytes32 initHash) external override onlyOwner returns (bool) {
        require(_factory != address(0), "GoosebumpsRouterPairs: FACTORY_NO_ADDRESS");
        return factories.set(_factory, initHash);
    }
    function removeFactory(address _factory) external override onlyOwner returns (bool) {
        require(_factory != address(0), "GoosebumpsRouterPairs: FACTORY_NO_ADDRESS");
        return factories.remove(_factory);
    }
    function hasFactory(address _factory) public override view returns (bool) {
        require(_factory != address(0), "GoosebumpsRouterPairs: FACTORY_NO_ADDRESS");
        return factories.contains(_factory);
    }
    function allFactories() external override view returns (address[] memory) {
        address[] memory _allFactories = new address[](factories.length());
        for(uint256 idx = 0; idx < factories.length(); idx++) {
            (address factory,) = factories.at(idx);
            _allFactories[idx] = factory;
        }
        return _allFactories;
    }
    function setLPFee(address _factory, uint256 fee) external override onlyOwner {
        require(_factory != address(0), "GoosebumpsRouterPairs: FACTORY_NO_ADDRESS");
        lpFees[_factory] = fee;
    }
}
