// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import './libraries/GoosebumpsLibrary.sol';
import './libraries/TransferHelper.sol';
import './interfaces/IGoosebumpsRouter.sol';
import './interfaces/IGoosebumpsFactory.sol';
import './interfaces/IGoosebumpsRouterPair.sol';
import './interfaces/IGoosebumpsRouterPairs.sol';
import './interfaces/IERC20.sol';
import './interfaces/IWETH.sol';

contract GoosebumpsRouter is IGoosebumpsRouter {
    address public immutable override WETH;
    address public immutable override baseFactory;
    address public immutable override routerPairs;
    address public immutable override feeAggregator;

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
        address _aggregator
    ) {
        WETH = _WETH;
        baseFactory = _baseFactory;
        routerPairs = _routerPairs;
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
            require(IGoosebumpsFactory(baseFactory).createPair(tokenA, tokenB) != address(0), "GoosebumpsRouter: CREATE_PAIR_FAILED");
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
        IWETH(WETH).deposit{value: amountETH}();
        assert(IWETH(WETH).transfer(pair, amountETH));
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
        TransferHelper.safeTransferFrom(pair, msg.sender, pair, liquidity); // send liquidity to pair
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
        IWETH(WETH).withdraw(amountETH);
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
        permit(tokenA, tokenB, liquidity, deadline, approveMax, v, r ,s);
        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
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
        permit(token, WETH, liquidity, deadline, approveMax, v, r ,s);
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
        TransferHelper.safeTransfer(token, to, IERC20(token).balanceOf(address(this)));
        IWETH(WETH).withdraw(amountETH);
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
        permit(token, WETH, liquidity, deadline, approveMax, v, r ,s);
        amountETH = removeLiquidityETHSupportingFeeOnTransferTokens(
            token, liquidity, amountTokenMin, amountETHMin, to, deadline
        );
    }
    /**
     * @dev to avoids stack too deep errors
     */
    function permit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) internal {
        address pair = IGoosebumpsRouterPairs(routerPairs).pairFor(baseFactory, tokenA, tokenB);
        uint256 value = approveMax ? type(uint256).max : liquidity;
        IGoosebumpsRouterPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(
        address[] memory factories, 
        uint256[] memory amounts, 
        address[] memory path, 
        address _to, 
        uint256 feeAmount, 
        address feeToken
    ) internal {
        if (path[0] == feeToken) transferFeeWhenNeeded(msg.sender, feeToken, feeAmount);

        for (uint256 i = 0; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = GoosebumpsLibrary.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            address to = i < path.length - 2 
                ? IGoosebumpsRouterPairs(routerPairs).pairFor(factories[i + 1], output, path[i + 2])
                : _to;
            if (output == path[path.length - 1] && output == feeToken)
                amountOut += feeAmount;

            _trySwap(
                IGoosebumpsRouterPair(IGoosebumpsRouterPairs(routerPairs).pairFor(factories[i], input, output)),
                input == token0 ? uint256(0) : amountOut,
                input == token0 ? amountOut : uint256(0),
                to
            );

            if (output == path[path.length - 1] && output == feeToken)
                transferFeeWhenNeeded(to, feeToken, feeAmount);
        }
    }
    function swapExactTokensForTokens(
        address[] calldata factories,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        uint256 feeAmount;
        address feeToken;
        (amounts, feeAmount, feeToken) = IGoosebumpsRouterPairs(routerPairs).getAmountsOut(factories, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'GoosebumpsRouter: INSUFFICIENT_OUTPUT_AMOUNT');

        transferAndSwap(factories, amounts, path, to, feeAmount, feeToken);
    }
    function swapTokensForExactTokens(
        address[] calldata factories,
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        uint256 feeAmount;
        address feeToken;
        (amounts, feeAmount, feeToken) = IGoosebumpsRouterPairs(routerPairs).getAmountsIn(factories, amountOut, path);

        uint256 totalAmount0 = amounts[0];
        if (path[0] == feeToken) totalAmount0 += feeAmount;
        require(totalAmount0 <= amountInMax, 'GoosebumpsRouter: EXCESSIVE_INPUT_AMOUNT');

        transferAndSwap(factories, amounts, path, to, feeAmount, feeToken);
    }
    function swapExactETHForTokens(
        address[] calldata factories,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override payable ensure(deadline) returns (uint256[] memory amounts) {
        require(path[0] == WETH, 'GoosebumpsRouter: INVALID_PATH');

        uint256 feeAmount;
        address feeToken;
        (amounts, feeAmount, feeToken) = IGoosebumpsRouterPairs(routerPairs).getAmountsOut(factories, msg.value, path);

        require(amounts[amounts.length - 1] >= amountOutMin, 'GoosebumpsRouter: INSUFFICIENT_OUTPUT_AMOUNT');

        uint256 totalAmount0 = amounts[0];
        if (path[0] == feeToken) totalAmount0 += feeAmount;
        IWETH(WETH).deposit{value: totalAmount0}();
        assert(IWETH(WETH).transfer(IGoosebumpsRouterPairs(routerPairs).pairFor(factories[0], path[0], path[1]), amounts[0]));

        _swap(factories, amounts, path, to, feeAmount, feeToken);
    }
    function swapTokensForExactETH(
        address[] calldata factories,
        uint256 amountOut,
        uint256 amountInMax, 
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        require(path[path.length - 1] == WETH, 'GoosebumpsRouter: INVALID_PATH');
        uint256 feeAmount;
        address feeToken;
        (amounts, feeAmount, feeToken) = IGoosebumpsRouterPairs(routerPairs).getAmountsIn(factories, amountOut, path);

        uint256 totalAmount0 = amounts[0];
        if (path[0] == feeToken) totalAmount0 += feeAmount;
        require(totalAmount0 <= amountInMax, 'GoosebumpsRouter: EXCESSIVE_INPUT_AMOUNT');

        transferAndSwap(factories, amounts, path, address(this), feeAmount, feeToken);

        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }
    function swapExactTokensForETH(
        address[] calldata factories,
        uint256 amountIn,
        uint256 amountOutMin, 
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
        require(path[path.length - 1] == WETH, 'GoosebumpsRouter: INVALID_PATH');
        uint256 feeAmount;
        address feeToken;
        (amounts, feeAmount, feeToken) = IGoosebumpsRouterPairs(routerPairs).getAmountsOut(factories, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'GoosebumpsRouter: INSUFFICIENT_OUTPUT_AMOUNT');

        transferAndSwap(factories, amounts, path, address(this), feeAmount, feeToken);

        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }
    function swapETHForExactTokens(
        address[] calldata factories,
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external virtual override payable ensure(deadline) returns (uint256[] memory amounts) {
        require(path[0] == WETH, 'GoosebumpsRouter: INVALID_PATH');

        uint256 feeAmount;
        address feeToken;
        (amounts, feeAmount, feeToken) = IGoosebumpsRouterPairs(routerPairs).getAmountsIn(factories, amountOut, path);

        uint256 totalAmount0 = amounts[0];
        if (path[0] == feeToken) totalAmount0 += feeAmount;
        require(totalAmount0 <= msg.value, 'GoosebumpsRouter: EXCESSIVE_INPUT_AMOUNT');
        IWETH(WETH).deposit{value: totalAmount0}();
        assert(IWETH(WETH).transfer(IGoosebumpsRouterPairs(routerPairs).pairFor(factories[0], path[0], path[1]), amounts[0]));

        _swap(factories, amounts, path, to, feeAmount, feeToken);

        // refund dust eth, if any
        if (msg.value > totalAmount0) TransferHelper.safeTransferETH(msg.sender, msg.value - totalAmount0);
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(address[] memory factories, address[] memory path, address _to) 
        internal virtual
    {
        for (uint256 i = 0; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = GoosebumpsLibrary.sortTokens(input, output);
            IGoosebumpsRouterPair pair = IGoosebumpsRouterPair(IGoosebumpsRouterPairs(routerPairs).pairFor(factories[i], input, output));

            uint256 amountInput;
            uint256 amountOutput;
            { // scope to avoid stack too deep errors
            (uint256 reserve0, uint256 reserve1,) = pair.getReserves();
            (uint256 reserveInput, uint256 reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
            amountInput = IERC20(input).balanceOf(address(pair)) - reserveInput;
            (amountOutput,) = IGoosebumpsRouterPairs(routerPairs).getAmountOut(
                factories[i],
                input,
                true,
                amountInput,
                reserveInput,
                reserveOutput
            );
            }
            (uint256 amount0Out, uint256 amount1Out) = input == token0 ? (uint256(0), amountOutput) : (amountOutput, uint256(0));

            // fee is only payed on the first or last token
            address to = i < path.length - 2 ? IGoosebumpsRouterPairs(routerPairs).pairFor(factories[i + 1], output, path[i + 2]) : _to;
            _trySwap(pair, amount0Out, amount1Out, to);
        }
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

        uint256 balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(factories, path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to) - balanceBefore >= amountOutMin,
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
        IWETH(WETH).deposit{value: amountIn}();
        
        (amountIn,) = subtractFee(msg.sender, WETH, amountIn);

        assert(IWETH(WETH).transfer(IGoosebumpsRouterPairs(routerPairs).pairFor(factories[0], path[0], path[1]), amountIn));

        uint256 balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(factories, path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to) - balanceBefore >= amountOutMin,
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

        _swapSupportingFeeOnTransferTokens(factories, path, address(this));
        uint256 amountOut = IERC20(WETH).balanceOf(address(this));
        require(amountOut >= amountOutMin, 'GoosebumpsRouter: INSUFFICIENT_OUTPUT_AMOUNT');

        IWETH(WETH).withdraw(amountOut);
        TransferHelper.safeTransferETH(to, amountOut);
    }
    /**
     * @dev to avoids stack too deep errors
     */
    function transferAndSwap(
        address[] calldata factories,
        uint256[] memory amounts,
        address[] calldata path,
        address to,
        uint256 feeAmount,
        address feeToken
    ) internal {
        TransferHelper.safeTransferFrom(
            path[0],
            msg.sender,
            IGoosebumpsRouterPairs(routerPairs).pairFor(factories[0], path[0], path[1]),
            amounts[0]
        );

        _swap(factories, amounts, path, to, feeAmount, feeToken);
    }
    function _trySwap(IGoosebumpsRouterPair pair, uint256 amount0Out, uint256 amount1Out, address to) internal {
        try pair.swap(amount0Out, amount1Out, to, new bytes(0)) {
        } catch (bytes memory /*lowLevelData*/) {
            pair.swap(amount0Out, amount1Out, to);
        }
    }
    function subtractFee(address from, address token, uint256 amount) 
        internal virtual returns(uint256 amountLeft, uint256 fee) 
    {
        (fee, amountLeft) = IFeeAggregator(feeAggregator).calculateFee(token, amount);
        transferFeeWhenNeeded(from, token, fee);
    }
    function transferFeeWhenNeeded(address from, address token, uint256 fee) internal virtual {
        if (fee > 0) {
            TransferHelper.safeTransferFrom(token, from, feeAggregator, fee);
        }
    }
}
