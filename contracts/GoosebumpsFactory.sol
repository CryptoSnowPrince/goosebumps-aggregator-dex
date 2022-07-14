// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import './interfaces/IGoosebumpsFactory.sol';
import './GoosebumpsPair.sol';

contract GoosebumpsFactory is IGoosebumpsFactory {
    bytes32 public constant INIT_CODE_PAIR_HASH = keccak256(abi.encodePacked(type(GoosebumpsPair).creationCode));
    address public override feeTo;
    address public override feeToSetter;

    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;

    constructor (address _feeToSetter) {
        require(_feeToSetter != address(0), "GoosebumpsFactory: ZERO_ADDRESS");
        feeToSetter = _feeToSetter;
    }

    function allPairsLength() external override view returns (uint) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        require(tokenA != tokenB, 'GoosebumpsFactory: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'GoosebumpsFactory: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'GoosebumpsFactory: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(GoosebumpsPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        GoosebumpsPair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external override {
        require(msg.sender == feeToSetter, 'GoosebumpsFactory: FORBIDDEN');
        require(_feeTo != address(0), "GoosebumpsFactory: ZERO_ADDRESS");
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) external override {
        require(msg.sender == feeToSetter, 'GoosebumpsFactory: FORBIDDEN');
        require(_feeToSetter != address(0), "GoosebumpsFactory: ZERO_ADDRESS");
        feeToSetter = _feeToSetter;
    }
}
