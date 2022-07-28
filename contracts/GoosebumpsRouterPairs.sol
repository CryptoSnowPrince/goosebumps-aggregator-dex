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

    event LogSetFeeAggregator(address indexed aggregator);
    event LogSetFactory(address indexed factory, bytes32 initHash, bool newFactory);
    event LogRemoveFactory(address indexed factory);
    event LogSetLPFee(address indexed factory, uint256 lpFee);

    modifier validFactory(address factory) {
        require(hasFactory(factory), 'GoosebumpsRouterPairs: INVALID_FACTORY');
        _;
    }

    constructor(address _aggregator) {
        require(_aggregator != address(0), "GoosebumpsRouterPairs: ZERO_ADDRESS");
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
    function getAmountOut(address factory, uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        external view override returns (uint256 amountOut, uint256 fee)
    {
        (fee, amountIn) = IFeeAggregator(feeAggregator).calculateFeeAndAmountOut(amountIn);
        amountOut = GoosebumpsLibrary.getAmountOut(amountIn, reserveIn, reserveOut, getLPFee(factory));
    }
    function getAmountOut(
        address factory,
        bool feePayed,
        uint256 amountIn, 
        uint256 reserveIn,
        uint256 reserveOut
    ) external view override returns (uint256 amountOut, uint256 fee)
    {
        if (!feePayed) {
            (fee, amountIn) = IFeeAggregator(feeAggregator).calculateFeeAndAmountOut(amountIn);
        }
        amountOut = GoosebumpsLibrary.getAmountOut(amountIn, reserveIn, reserveOut, getLPFee(factory));
    }
    /**
     * Note totalAmountIn = amountIn + fee
     */
    function getAmountIn(address factory, uint256 amountOut, uint256 reserveIn, uint256 reserveOut)
        external view override returns (uint256 amountIn, uint256 fee) 
    {
        amountIn = GoosebumpsLibrary.getAmountIn(amountOut, reserveIn, reserveOut, getLPFee(factory));
        (fee,) = IFeeAggregator(feeAggregator).calculateFeeAndAmountIn(amountIn);
    }
    /**
     * Note totalAmountIn = amountIn + fee
     */
    function getAmountIn(
        address factory,
        bool feePayed,
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) external view override returns (uint256 amountIn, uint256 fee) 
    {
        amountIn = GoosebumpsLibrary.getAmountIn(amountOut, reserveIn, reserveOut, getLPFee(factory));
        if (!feePayed) {
            (fee,) = IFeeAggregator(feeAggregator).calculateFeeAndAmountIn(amountIn);
        }
    }
    function getAmountsOut(address[] calldata _factories, uint256 amountIn, address[] calldata path)
        external view override returns (uint256[] memory amounts, uint256 feeAmount) 
    {
        (bytes32[] memory hashes, uint256[] memory fees) = getInitHashesAndFees(_factories);
        return GoosebumpsLibrary.getAmountsOut(feeAggregator, _factories, hashes, amountIn, path, fees);
    }
    function getAmountsIn(address[] calldata _factories, uint256 amountOut, address[] calldata path)
        external view override returns (uint256[] memory amounts, uint256 feeAmount) 
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
    
    function setFeeAggregator(address aggregator) external override onlyMultiSig {
        require(aggregator != address(0), "GoosebumpsRouterPairs: ZERO_ADDRESS");
        require(aggregator != feeAggregator, "GoosebumpsRouterPairs: SAME_ADDRESS");
        feeAggregator = aggregator;

        emit LogSetFeeAggregator(aggregator);
    }
    function setFactory(address _factory, bytes32 initHash) external override onlyMultiSig {
        require(_factory != address(0), "GoosebumpsRouterPairs: ZERO_ADDRESS");
        // if new Factory, return true, if only set `initHash`, return false.
        bool newFactory = factories.set(_factory, initHash);

        emit LogSetFactory(_factory, initHash, newFactory);
    }
    function removeFactory(address _factory) external override onlyMultiSig {
        require(_factory != address(0), "GoosebumpsRouterPairs: ZERO_ADDRESS");
        require(factories.remove(_factory), "GoosebumpsRouterPairs: NOT_FOUND");

        emit LogRemoveFactory(_factory);
    }
    function hasFactory(address _factory) public override view returns (bool) {
        require(_factory != address(0), "GoosebumpsRouterPairs: ZERO_ADDRESS");
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
    function setLPFee(address _factory, uint256 _lpFee) external override onlyMultiSig {
        require(_factory != address(0), "GoosebumpsRouterPairs: ZERO_ADDRESS");
        require(lpFees[_factory] != _lpFee, "GoosebumpsRouterPairs: SAME_VALUE");
        lpFees[_factory] = _lpFee;

        emit LogSetLPFee(_factory, _lpFee);
    }
}
