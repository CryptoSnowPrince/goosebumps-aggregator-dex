// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "./interfaces/IGoosebumpsRouter.sol";
import "./interfaces/IFeeAggregator.sol";
import "./interfaces/IERC20.sol";
import "./libraries/TransferHelper.sol";
import "./utils/Ownable.sol";

contract FeeAggregator is IFeeAggregator, Ownable {
    event LogWithdrawalETH(address indexed recipient, uint256 amount);
    event LogWithdrawToken(address indexed token, address indexed recipient, uint256 amount);
    event LogSetGoosebumpsFee(uint256 fee);

    /**
     * @notice Percentage which get deducted from a swap (1 = 100 / FEE_DENOMINATOR %)
     */
    uint256 public goosebumpsFee;
    uint256 public constant FEE_DENOMINATOR = 10000;

    constructor() {
        // 0.05%
        goosebumpsFee = 5;
    }

    receive() external payable {}
    fallback() external payable {}

    /**
     * @notice returns the fee and the amountOut for the amountIn given
     * @param amountIn input amount
     */
    function calculateFeeAndAmountOut(uint256 amountIn) external override view returns (uint256 fee, uint256 amountOut) {
        amountOut = amountIn * (FEE_DENOMINATOR - goosebumpsFee) / FEE_DENOMINATOR;
        fee = amountIn - amountOut;
    }

    /**
     * @notice returns the fee and the amountIn for the amountOut given
     * @param amountOut output amount
     */
    function calculateFeeAndAmountIn(uint256 amountOut) external override view returns (uint256 fee, uint256 amountIn) {
        amountIn = amountOut * FEE_DENOMINATOR / (FEE_DENOMINATOR - goosebumpsFee);
        fee = amountIn - amountOut;
    }

    /**
     * @notice set the percentage which get deducted from a swap (1 = 100 / FEE_DENOMINATOR %)
     * @param fee percentage to set as fee
     */
    function setGoosebumpsFee(uint256 fee) external override onlyMultiSig {
        require(fee <= FEE_DENOMINATOR * 30 / 100, "FeeAggregator: FEE_MIN_0_MAX_30");
        require(fee != goosebumpsFee, "FeeAggregator: SAME_VALUE");
        goosebumpsFee = fee;

        emit LogSetGoosebumpsFee(fee);
    }

    /**
     * @notice  onlyMultiSig will withdraw ETH and will use to benefit the Empire token holders.
     */
    function withdrawETH(address payable recipient, uint256 amount) external onlyMultiSig
    {
        require(amount <= (address(this)).balance, "INSUFFICIENT_FUNDS");
        recipient.transfer(amount);
        emit LogWithdrawalETH(recipient, amount);
    }

    /**
     * @notice  onlyMultiSig will withdraw ERC20 token that have the price and then will use to benefit the Empire token holders.
     #          Should not be withdrawn scam token.
     */
    function withdrawToken(IERC20 token, address recipient, uint256 amount) external onlyMultiSig {
        require(amount <= token.balanceOf(address(this)), "INSUFFICIENT_FUNDS");
        require(token.transfer(recipient, amount), "Transfer Fail");

        emit LogWithdrawToken(address(token), recipient, amount);
    }

    function swapExactTokensForTokens(
        IGoosebumpsRouter router,
        address[] calldata factories,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external onlyMultiSig {
        require(IERC20(path[0]).balanceOf(address(this)) >= amountIn, "FeeAggregator: NO_FEE_TOKEN_BALANCE");
        TransferHelper.safeApprove(path[0], address(router), amountIn);

        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(factories, amountIn, amountOutMin, path, to, deadline);
    }

    function swapExactTokensForETH(
        IGoosebumpsRouter router,
        address[] calldata factories,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external onlyMultiSig {
        require(IERC20(path[0]).balanceOf(address(this)) >= amountIn, "FeeAggregator: NO_FEE_TOKEN_BALANCE");
        TransferHelper.safeApprove(path[0], address(router), amountIn);

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(factories, amountIn, amountOutMin, path, to, deadline);
    }
}
