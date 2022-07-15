// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import './GoosebumpsPair.sol';

contract GoosebumpsFactory is IGoosebumpsFactory {
    bytes32 public constant INIT_CODE_PAIR_HASH = keccak256(abi.encodePacked(type(GoosebumpsPair).creationCode));
    address public override feeTo;
    /**
     * @dev Must be Multi-Signature Wallet.
     */
    address public override multiSigFeeToSetter;

    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;

    event LogSetFeeTo(address feeTo);
    event LogSetFeeToSetter(address multiSigFeeToSetter);

    constructor (address _multiSigFeeToSetter) {
        require(_multiSigFeeToSetter != address(0), "GoosebumpsFactory: ZERO_ADDRESS");
        multiSigFeeToSetter = _multiSigFeeToSetter;
    }

    function allPairsLength() external override view returns (uint256) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) external override returns (address pair) {
        require(tokenA != tokenB, 'GoosebumpsFactory: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'GoosebumpsFactory: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'GoosebumpsFactory: PAIR_EXISTS'); // single check is sufficient
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        pair = address(new GoosebumpsPair{salt: salt}(token0, token1));
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external override {
        require(msg.sender == multiSigFeeToSetter, 'GoosebumpsFactory: FORBIDDEN');
        require(_feeTo != address(0), "GoosebumpsFactory: ZERO_ADDRESS");
        require(_feeTo != feeTo, "GoosebumpsFactory: SAME_ADDRESS");
        feeTo = _feeTo;

        emit LogSetFeeTo(_feeTo);
    }

    function setFeeToSetter(address _multiSigFeeToSetter) external override {
        require(msg.sender == multiSigFeeToSetter, 'GoosebumpsFactory: FORBIDDEN');
        require(_multiSigFeeToSetter != address(0), "GoosebumpsFactory: ZERO_ADDRESS");
        require(_multiSigFeeToSetter != multiSigFeeToSetter, "GoosebumpsFactory: SAME_ADDRESS");
        multiSigFeeToSetter = _multiSigFeeToSetter;

        emit LogSetFeeToSetter(_multiSigFeeToSetter);
    }
}
