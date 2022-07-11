// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "./interfaces/IDPexRouter.sol";
import "./interfaces/IFeeAggregator.sol";
import "./interfaces/IWETH.sol";
import "./utils/Ownable.sol";

contract FeeAggregator is IFeeAggregator, Ownable {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    event LogWithdrawalETH(address indexed recipient, uint256 amount);
    event LogWithdrawToken(
        address indexed token,
        address indexed recipient,
        uint256 amount
    );

    //== Variables ==
    EnumerableSetUpgradeable.AddressSet private _feeTokens; // all the token where a fee is deducted from on swap

    address public WETH;
    /**
     * @notice percentage which get deducted from a swap (1 = 0.1%)
     */
    uint256 public goosebumpsFee;
    /**
     * @notice token fees gathered in the current period
     */
    mapping(address => uint256) public tokensGathered;

    uint256 private constant MAX_INT = 2**256 - 1;

    constructor(address _baseToken) {
        goosebumpsFee = 1;
        WETH = _baseToken;
    }

    receive() external payable {
        if (msg.sender != WETH) {
            IWETH(WETH).deposit{value: msg.value}();
            addTokenFee(WETH, msg.value);
        }
    }

    //== MODIFIERS ==
    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'FeeAggregator: EXPIRED');
        _;
    }

    //== VIEW ==
    /**
     * @notice return all the tokens where a fee is deducted from on swap
     */
    function feeTokens() external override view returns (address[] memory) {
        address[] memory tokens = new address[](_feeTokens.length());
        for(uint256 idx = 0; idx < _feeTokens.length(); idx++) {
            tokens[idx] = _feeTokens.at(idx);
        }
        return tokens;
    }
    /**
     * @notice checks if the token is a token where a fee is deducted from on swap
     * @param token fee token to check
     */
    function isFeeToken(address token) public override view returns (bool) {
        return _feeTokens.contains(token);
    }

    /**
     * @notice returns the fee for the amount given
     * @param amount amount to calculate the fee for
     */
    function calculateFee(uint256 amount) public override view returns (uint256 fee, uint256 amountLeft) {
        amountLeft = ((amount * 1000) - (amount * goosebumpsFee)) / 1000;
        fee = amount - amountLeft;
    }
    /**
     * @notice returns the fee for the amount given, but only if the token is in the feetokens list
     * @param token token to check if it exists in the feetokens list
     * @param amount amount to calculate the fee for
     */
    function calculateFee(address token, uint256 amount) external override view 
        returns (uint256 fee, uint256 amountLeft)
    {
        if (!_feeTokens.contains(token)) { return (0, amount); }
        return calculateFee(amount);
    }

    //== SET INTERNAL VARIABLES==
    /**
     * @notice add a token to deduct a fee for on swap
     * @param token fee token to add
     */
    function addFeeToken(address token) public override onlyOwner {
        require(!_feeTokens.contains(token), "FeeAggregator: ALREADY_FEE_TOKEN");
        _feeTokens.add(token);
        approveFeeToken(token);
    }
    /**
     * @notice add fee tokens to deduct a fee for on swap
     * @param tokens fee tokens to add
     */
    function addFeeTokens(address[] calldata tokens) external override onlyOwner {
        for(uint256 idx = 0; idx < tokens.length; idx++) {
            addFeeToken(tokens[idx]);
        }
    }
    /**
     * @notice approve a single fee token on the router
     * @param token fee token to approve
     */
    function approveFeeToken(address token) public override onlyOwner {
        IERC20Upgradeable(token).approve(router(), MAX_INT);
    }
    /**
     * @notice approve all fee tokens on the router
     */
    function approveFeeTokens() external override onlyOwner {
        for(uint256 idx = 0; idx < _feeTokens.length(); idx++) {
            address token = _feeTokens.at(idx);
            approveFeeToken(token);
        }
    }
    /**
     * @notice remove a token to deduct a fee for on swap
     * @param token fee token to add
     */
    function removeFeeToken(address token) external override onlyOwner {
        require(_feeTokens.contains(token), "FeeAggregator: NO_FEE_TOKEN");
        _feeTokens.remove(token);
    }
    /**
     * @notice set the percentage which get deducted from a swap (1 = 0.1%)
     * @param fee percentage to set as fee
     */
    function setGoosebumpsFee(uint256 fee) external override onlyOwner {
        require(fee >= 0 && fee <= 490, "FeeAggregator: FEE_MIN_0_MAX_49");
        goosebumpsFee = fee;
    }
    
    /**
     * @notice Adds a fee to the tokensGathered list. For example from the DPEX router
     * @param token fee token to check
     * @param fee fee to add to the tokensGathered list
     */
    function addTokenFee(address token, uint256 fee) public override {
        require (_feeTokens.contains(token), "Token is not a feeToken");
        tokensGathered[token] += fee;
    }
    /**
     * @notice Adds multiple fees to the tokensGathered list. For example from the DPEX router
     * @param tokens fee tokens to check
     * @param fees fees to add to the tokensGathered list
     */
    function addTokenFees(address[] memory tokens, uint256[] memory fees) external override {
        require (tokens.length == fees.length, "Token is not a feeToken");
        for(uint256 idx = 0; idx < tokens.length; idx++) {
            require (_feeTokens.contains(tokens[idx]), "Token is not a feeToken");
            tokensGathered[tokens[idx]] += fees[idx];
        }
    }

    /**
     * @notice  Owner will withdraw ETH and will use to benefit the Empire token holders.
     */
    function withdrawETH(address payable recipient, uint256 amount)
        external
        onlyOwner
    {
        require(amount <= (address(this)).balance, "INSUFFICIENT_FUNDS");
        recipient.transfer(amount);
        emit LogWithdrawalETH(recipient, amount);
    }

    /**
     * @notice  Owner will withdraw ERC20 token that have the price and then will use to benefit the Empire token holders.
     #          Should not be withdrawn scam token.
     */
    function withdrawToken(
        IERC20 token,
        address recipient,
        uint256 amount
    ) external onlyOwner {
        require(amount <= token.balanceOf(address(this)), "INSUFFICIENT_FUNDS");
        require(token.transfer(recipient, amount), "Transfer Fail");

        emit LogWithdrawToken(address(token), recipient, amount);
    }

    /**
     * @notice sells all fees for PSI and reflects them over the PSI holders
     */
    function reflectFees(uint256 deadline) external override onlyOwner ensure(deadline) {
        uint256 psiBalanceBefore = IERC20Upgradeable(psi).balanceOf(address(this));
        _sellFeesToPSI();
        uint256 psiFeeBalance = IERC20Upgradeable(psi).balanceOf(address(this)) - psiBalanceBefore;
        if (tokensGathered[psi] > 0) {
            psiFeeBalance += tokensGathered[psi];
            tokensGathered[psi] = 0;
        }

        IPSI(psi).reflect(psiFeeBalance);
    }
    /**
     * @notice sells a single fee for PSI and reflects them over the PSI holders
     */
    function reflectFee(address token, uint256 deadline) external override onlyOwner ensure(deadline) {
        require(_feeTokens.contains(token), "FeeAggregator: NO_FEE_TOKEN");
        uint256 psiBalanceBefore = IERC20Upgradeable(psi).balanceOf(address(this));
        uint256 psiFeeBalance;
        if (token == psi) {
            psiFeeBalance = tokensGathered[psi];
            require(psiFeeBalance > 0, "FeeAggregator: NO_FEE_TOKEN_BALANCE");
        } else {
            _sellFeeToPSI(token);
            psiFeeBalance = IERC20Upgradeable(psi).balanceOf(address(this)) - psiBalanceBefore;
        }

        IPSI(psi).reflect(psiFeeBalance);
    }
    function _sellFeesToPSI() internal {
        for(uint256 idx = 0; idx < _feeTokens.length(); idx++) {
            address token = _feeTokens.at(idx);
            uint256 tokenBalance = IERC20Upgradeable(token).balanceOf(address(this));
            if (token != WETH && token != psi && tokenBalance > 0) {
                tokensGathered[token] = 0;
                address[] memory path = new address[](2);
                path[0] = token;
                path[1] = WETH;
                IDPexRouter(router()).swapAggregatorToken(tokenBalance, path, address(this));
            }
        }

        _sellBaseTokenToPSI();
    }
    function _sellFeeToPSI(address token) internal {
        uint256 tokenBalance = IERC20Upgradeable(token).balanceOf(address(this));
        require(tokenBalance > 0, "FeeAggregator: NO_FEE_TOKEN_BALANCE");
        if (token != WETH && token != psi && tokenBalance > 0) {
            tokensGathered[token] = 0;
            address[] memory path = new address[](3);
            path[0] = token;
            path[1] = WETH;
            path[2] = psi;
            IDPexRouter(router()).swapAggregatorToken(tokenBalance, path, address(this));
        } else if(token == WETH) {
            _sellBaseTokenToPSI();
        }
    }
    function _sellBaseTokenToPSI() internal {
        uint256 balance = IERC20Upgradeable(WETH).balanceOf(address(this));
        if (balance <= 0) return;

        tokensGathered[WETH] = 0;
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = psi;
        IDPexRouter(router()).swapAggregatorToken(balance, path, address(this));
    }
}
