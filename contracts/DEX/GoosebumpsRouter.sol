// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import './libraries/GoosebumpsLibrary.sol';
import './libraries/TransferHelper.sol';
import './interfaces/IGoosebumpsRouter.sol';
import './interfaces/IGoosebumpsFactory.sol';
import './interfaces/IERC20.sol';
import './interfaces/IWETH.sol';

contract GoosebumpsRouter is IGoosebumpsRouter {
    address public immutable override WETH;
    address public immutable override baseFactory;
    address public override routerPairs;
    address public override feeAggregator;

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, 'GoosebumpsRouter: EXPIRED');
        _;
    }
    modifier onlyAggregator() {
        require(feeAggregator == msg.sender, "GoosebumpsRouter: ONLY_FEE_AGGREGATOR");
        _;
    }

    constructor(
        address _baseFactory,
        address _routerPairs,
        address _WETH,
        address _aggregator,
    ) {
        baseFactory = _baseFactory;
        routerPairs = _routerPairs;
        WETH = _WETH;
        feeAggregator = _aggregator;
    }

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal virtual returns (uint256 amountA, uint256 amountB) {
        // create the pair if it doesn't exist yet
        if (IGoosebumpsFactory(baseFactory).getPair(tokenA, tokenB) == address(0)) {
            IGoosebumpsFactory(baseFactory).createPair(tokenA, tokenB);
        }
        (uint256 reserveA, uint256 reserveB) = IGoosebumpsRouterPairs(routerPairs).getReserves(baseFactory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = GoosebumpsLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, 'GoosebumpsRouter: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = GoosebumpsLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'GoosebumpsRouter: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) 
    returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = IGoosebumpsRouterPairs(routerPairs).pairFor(baseFactory, tokenA, tokenB);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = IGoosebumpsRouterPair(pair).mint(to);
    }
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external virtual override payable ensure(deadline) 
    returns (uint256 amountToken, uint256 amountETH, uint256 liquidity) {
        (amountToken, amountETH) = _addLiquidity(
            token,
            WETH,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );
        address pair = IGoosebumpsRouterPairs(routerPairs).pairFor(baseFactory, token, WETH);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        IGoosebumpsWETHWrapper(WETHWrapper).deposit{value: amountETH}();
        assert(IGoosebumpsWETHWrapper(WETHWrapper).transfer(pair, amountETH));
        liquidity = IGoosebumpsRouterPair(pair).mint(to);
        // refund dust eth, if any
        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountA, uint256 amountB) {
        address pair = IGoosebumpsRouterPairs(routerPairs).pairFor(baseFactory, tokenA, tokenB);
        IGoosebumpsRouterPair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint256 amount0, uint256 amount1) = IGoosebumpsRouterPair(pair).burn(to);
        (address token0,) = GoosebumpsLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, 'GoosebumpsRouter: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'GoosebumpsRouter: INSUFFICIENT_B_AMOUNT');
    }
    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountToken, uint256 amountETH) {
        (amountToken, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, amountToken);
        assert(IWETH(WETH).transfer(WETHWrapper, amountETH));
        IGoosebumpsWETHWrapper(WETHWrapper).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint256 amountA, uint256 amountB) {
        _permit(tokenA, tokenB, liquidity, deadline, approveMax, v, r ,s);
        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
    }
    function _permit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) internal {
        IGoosebumpsRouterPair(IGoosebumpsRouterPairs(routerPairs).pairFor(baseFactory, tokenA, tokenB)).permit(
            msg.sender, 
            address(this), 
            approveMax ? uint(-1) : liquidity,
            deadline,
            v, r, s
        );
    }
    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint256 amountToken, uint256 amountETH) {
        IGoosebumpsRouterPair(IGoosebumpsRouterPairs(routerPairs).pairFor(baseFactory, token, WETH)).permit(
            msg.sender,
            address(this),
            approveMax ? uint(-1) : liquidity,
            deadline,
            v, r, s
        );
        (amountToken, amountETH) = removeLiquidityETH(token, liquidity, amountTokenMin, amountETHMin, to, deadline);
    }

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) public virtual override ensure(deadline) returns (uint256 amountETH) {
        (, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, IBEP20(token).balanceOf(address(this)));
        assert(IWETH(WETH).transfer(WETHWrapper, amountETH));
        IGoosebumpsWETHWrapper(WETHWrapper).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint256 amountETH) {
        address pair = IGoosebumpsRouterPairs(routerPairs).pairFor(baseFactory, token, WETH);
        uint256 value = approveMax ? uint(-1) : liquidity;
        IGoosebumpsRouterPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        amountETH = removeLiquidityETHSupportingFeeOnTransferTokens(
            token, liquidity, amountTokenMin, amountETHMin, to, deadline
        );
    }

    // **** SWAP ****
    function _swap(
        address[] memory factories, 
        uint[] memory amounts, 
        address[] memory path, 
        address _to, 
        uint256 feeAmount, 
        address feeToken
    ) internal {
        // send initial amount
        transferTokensOrWETH(
            path[0],
            msg.sender,
            IGoosebumpsRouterPairs(routerPairs).pairFor(factories[0], path[0],
            path[1]),
            amounts[0]
        );
        if (path[0] == feeToken) transferFeeWhenNeeded(msg.sender, feeToken, feeAmount);

        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = GoosebumpsLibrary.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            address to = i < path.length - 2 
                ? IGoosebumpsRouterPairs(routerPairs).pairFor(factories[i + 1], output, path[i + 2])
                : _to;
            if (to == WETHWrapper && output == path[path.length - 1] && output == feeToken)`
                amountOut += feeAmount;

            _trySwap(
                IGoosebumpsRouterPair(IGoosebumpsRouterPairs(routerPairs).pairFor(factories[i], input, output)),
                input == token0 ? uint256(0) : amountOut,
                input == token0 ? amountOut : uint256(0),
                to
            );

            if (to == WETHWrapper && output == path[path.length - 1] && output == feeToken)
                transferFeeWhenNeeded(WETHWrapper, feeToken, feeAmount);
        }
    }
    function swapExactTokensForTokens(
        address[] calldata factories,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        uint256 feeAmount;
        address feeToken;
        (amounts, feeAmount, feeToken) = IGoosebumpsRouterPairs(routerPairs).getAmountsOut(factories, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'GoosebumpsRouter: INSUFFICIENT_OUTPUT_AMOUNT');

        _swap(factories, amounts, path, to, feeAmount, feeToken);
    }
    function swapTokensForExactTokens(
        address[] calldata factories,
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        uint256 feeAmount;
        address feeToken;
        (amounts, feeAmount, feeToken) = IGoosebumpsRouterPairs(routerPairs).getAmountsIn(factories, amountOut, path);

        uint256 totalAmount0 = amounts[0];
        if (path[0] == feeToken) totalAmount0 += feeAmount;
        require(totalAmount0 <= amountInMax, 'GoosebumpsRouter: EXCESSIVE_INPUT_AMOUNT');

        _swap(factories, amounts, path, to, feeAmount, feeToken);
    }
    function swapExactETHForTokens(
        address[] calldata factories,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override payable ensure(deadline) returns (uint[] memory amounts) {
        require(path[0] == WETH, 'GoosebumpsRouter: INVALID_PATH');

        uint256 feeAmount;
        address feeToken;
        (amounts, feeAmount, feeToken) = IGoosebumpsRouterPairs(routerPairs).getAmountsOut(factories, msg.value, path);

        require(amounts[amounts.length - 1] >= amountOutMin, 'GoosebumpsRouter: INSUFFICIENT_OUTPUT_AMOUNT');

        uint256 totalAmount0 = amounts[0];
        if (path[0] == feeToken) totalAmount0 += feeAmount;
        IGoosebumpsWETHWrapper(WETHWrapper).deposit{value: totalAmount0}();

        _swap(factories, amounts, path, to, feeAmount, feeToken);
    }
    function swapTokensForExactETH(
        address[] calldata factories,
        uint256 amountOut,
        uint256 amountInMax, 
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        require(path[path.length - 1] == WETH, 'GoosebumpsRouter: INVALID_PATH');
        uint256 feeAmount;
        address feeToken;
        (amounts, feeAmount, feeToken) = IGoosebumpsRouterPairs(routerPairs).getAmountsIn(factories, amountOut, path);

        uint256 totalAmount0 = amounts[0];
        if (path[0] == feeToken) totalAmount0 += feeAmount;
        require(totalAmount0 <= amountInMax, 'GoosebumpsRouter: EXCESSIVE_INPUT_AMOUNT');

        amounts = _swapTokensForETH(factories, amounts, path, to, feeAmount, feeToken);
    }
    function swapExactTokensForETH(
        address[] calldata factories,
        uint256 amountIn,
        uint256 amountOutMin, 
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        require(path[path.length - 1] == WETH, 'GoosebumpsRouter: INVALID_PATH');
        uint256 feeAmount;
        address feeToken;
        (amounts, feeAmount, feeToken) = IGoosebumpsRouterPairs(routerPairs).getAmountsOut(factories, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'GoosebumpsRouter: INSUFFICIENT_OUTPUT_AMOUNT');

        amounts = _swapTokensForETH(factories, amounts, path, to, feeAmount, feeToken);
    }
    function _swapTokensForETH(
        address[] calldata factories,
        uint[] memory amounts,
        address[] calldata path, 
        address to,
        uint256 feeAmount,
        address feeToken
    ) internal returns (uint[] memory) {
        _swap(factories, amounts, path, WETHWrapper, feeAmount, feeToken);

        IGoosebumpsWETHWrapper(WETHWrapper).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
        return amounts;
    }
    function swapETHForExactTokens(
        address[] calldata factories,
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override payable ensure(deadline) returns (uint[] memory amounts) {
        require(path[0] == WETH, 'GoosebumpsRouter: INVALID_PATH');

        uint256 feeAmount;
        address feeToken;
        (amounts, feeAmount, feeToken) = IGoosebumpsRouterPairs(routerPairs).getAmountsIn(factories, amountOut, path);

        uint256 totalAmount0 = amounts[0];
        if (path[0] == feeToken) totalAmount0 += feeAmount;
        require(totalAmount0 <= msg.value, 'GoosebumpsRouter: EXCESSIVE_INPUT_AMOUNT');
        IGoosebumpsWETHWrapper(WETHWrapper).deposit{value: totalAmount0}();

        _swap(factories, amounts, path, to, feeAmount, feeToken);

        // refund dust eth, if any
        if (msg.value > amounts[0]) TransferHelper.safeTransferETH(msg.sender, msg.value - totalAmount0);
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(address[] memory factories, address[] memory path, address _to) 
        internal virtual
    {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = GoosebumpsLibrary.sortTokens(input, output);
            IGoosebumpsRouterPair pair = IGoosebumpsRouterPair(IGoosebumpsRouterPairs(routerPairs).pairFor(factories[i], input, output));

            // fee is only payed on the first or last token
            address to = i < path.length - 2 
                ? IGoosebumpsRouterPairs(routerPairs).pairFor(factories[i + 1], output, path[i + 2])
                : _to;
            _trySwap(
                pair,
                input == token0 ? uint(0) : _getAmountOut(factories[i], pair, input, token0), 
                input == token0 ? _getAmountOut(factories[i], pair, input, token0) : uint(0),
                to
            );
        }
    }
    function _getAmountOut(address factory, IGoosebumpsRouterPair pair, address input, address token0) 
        internal virtual returns (uint256 amountOutput) 
    {
        (uint256 reserve0, uint256 reserve1,) = pair.getReserves();
        uint256 amountInput = IBEP20(input).balanceOf(address(pair)).sub(input == token0 ? reserve0 : reserve1);
        (amountOutput,) = IGoosebumpsRouterPairs(routerPairs).getAmountOut(
            factory,
            input,
            true, 
            amountInput,
            input == token0 ? reserve0 : reserve1,
            input == token0 ? reserve1 : reserve0
        );
    }
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        address[] calldata factories,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) {
        (amountIn,) = subtractFee(msg.sender, path[0], amountIn);

        TransferHelper.safeTransferFrom(
            path[0], msg.sender, IGoosebumpsRouterPairs(routerPairs).pairFor(factories[0], path[0], path[1]), amountIn
        );

        uint256 balanceBefore = IBEP20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(factories, path, to);
        require(
            IBEP20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'GoosebumpsRouter: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        address[] calldata factories,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override payable ensure(deadline) {
        require(path[0] == WETH, 'GoosebumpsRouter: INVALID_PATH');
        uint256 amountIn = msg.value;
        IGoosebumpsWETHWrapper(WETHWrapper).deposit{value: amountIn}();
        
        (amountIn,) = subtractFee(msg.sender, WETH, amountIn);

        assert(IGoosebumpsWETHWrapper(WETHWrapper).transfer(IGoosebumpsRouterPairs(routerPairs)
            .pairFor(factories[0], path[0], path[1]), amountIn));

        uint256 balanceBefore = IBEP20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(factories, path, to);
        require(
            IBEP20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'GoosebumpsRouter: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        address[] calldata factories,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) {
        require(path[path.length - 1] == WETH, 'GoosebumpsRouter: INVALID_PATH');

        (amountIn,) = subtractFee(msg.sender, path[0], amountIn);
        
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, IGoosebumpsRouterPairs(routerPairs).pairFor(factories[0], path[0], path[1]), amountIn
        );

        _swapSupportingFeeOnTransferTokens(factories, path, WETHWrapper);
        uint256 amountOut = IBEP20(WETH).balanceOf(WETHWrapper);
        require(amountOut >= amountOutMin, 'GoosebumpsRouter: INSUFFICIENT_OUTPUT_AMOUNT');

        IGoosebumpsWETHWrapper(WETHWrapper).withdraw(amountOut);
        TransferHelper.safeTransferETH(to, amountOut);
    }

    function _trySwap(IGoosebumpsRouterPair pair, uint256 amount0Out, uint256 amount1Out, address to) internal {
        try pair.swap(amount0Out, amount1Out, to, new bytes(0)) {
        } catch (bytes memory /*lowLevelData*/) {
            pair.swap(amount0Out, amount1Out, to);
        }
    }

    
    /** Router internal modifiers */
    function setBaseFactory(address _baseFactory) external override onlyGovernor {
        require(_baseFactory != address(0), "GoosebumpsRouter: FACTORY_NO_ADDRESS");
        baseFactory = _baseFactory;
    }
    function setWETHWrapper(address wethWrapper) external override onlyGovernor {
        require(wethWrapper != address(0), "GoosebumpsRouter: WETHWrapper_NO_ADDRESS");
        WETHWrapper = wethWrapper;
    }


    /** Aggregator function helpers */
    function setFeeAggregator(address aggregator) external override onlyGovernor {
        require(aggregator != address(0), "GoosebumpsRouter: FEE_AGGREGATOR_NO_ADDRESS");
        feeAggregator = aggregator;
    }
    function swapAggregatorToken(
        uint256 amountIn,
        address[] calldata path,
        address to
    ) external virtual override onlyAggregator returns (uint256) {
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, IGoosebumpsRouterPairs(routerPairs).pairFor(baseFactory, path[0], path[1]), amountIn
        );
        uint256 balanceBefore = IBEP20(path[path.length - 1]).balanceOf(to);

        address[] memory factories = new address[](path.length - 1);
        for(uint256 idx = 0; idx < path.length - 1; idx++) {
            factories[idx] = baseFactory;
        }

        _swapSupportingFeeOnTransferTokens(factories, path, to);
        return IBEP20(path[path.length - 1]).balanceOf(to).sub(balanceBefore);
    }

    function subtractFee(address from, address token, uint256 amount) 
        internal virtual returns(uint256 amountLeft, uint256 fee) 
    {
        (fee, amountLeft) = IFeeAggregator(feeAggregator).calculateFee(token, amount);
        if (fee > 0) transferFeeWhenNeeded(from, token, fee);
    }
    function transferFeeWhenNeeded(address from, address token, uint256 fee) internal virtual {
        if (fee > 0) {
            uint256 balanceBefore = IBEP20(token).balanceOf(feeAggregator);
            transferTokensOrWETH(token, from, feeAggregator, fee);
            IFeeAggregator(feeAggregator).addTokenFee(
                token, 
                IBEP20(token).balanceOf(feeAggregator).sub(balanceBefore)
            );
        }
    }
    function transferTokensOrWETH(address token, address from, address to, uint256 amount) internal virtual {
        if (token != WETH) {
            TransferHelper.safeTransferFrom(token, from, to, amount);
        } else {
            assert(IGoosebumpsWETHWrapper(WETHWrapper).transfer(to, amount));
        }
    }
}
