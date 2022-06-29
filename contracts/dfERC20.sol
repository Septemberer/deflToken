// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./resources/pancake-swap/interfaces/IPancakeRouter02.sol";
import "./resources/pancake-swap/interfaces/IPancakePair.sol";
import "./resources/pancake-swap/interfaces/IPancakeFactory.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";


contract dfERC20 is ERC20, Ownable {
    using Address for address;
    using SafeMath for uint256;

    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply = 42000000 * 10**18;
    uint256 private constant LACC  = 2000 * 10**18;
    uint256 private accum_liq;

    string private _name = "DeFLateToken";
    string private _symbol = "DFLT";
    uint8 private _decimals = 18;
    bool private started;

    uint256 private _taxFee = 2;
    address private immutable _owner;

    uint256 private _liquidityFee = 2;

    uint256 private _burnFee = 1;
    address private constant DEAD = 0x000000000000000000000000000000000000dEaD;

    IPancakeRouter02 public router;
    address public pancakePair;

    IERC20Metadata public immutable liqToken;
    bool inSwapAndLiquify;

    event SwapAndLiquity(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );

    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    constructor(IERC20Metadata _liqToken, IPancakeRouter02 _router)
        ERC20(_name, _symbol)
    {
        _owner = _msgSender();
        liqToken = _liqToken;

        _mint(_msgSender(), _totalSupply);

        // pancakePair = IPancakeFactory(_router.factory()).createPair(
        //     address(this),
        //     address(_liqToken)
        // );
        router = _router;

        emit Transfer(address(0), _msgSender(), _totalSupply);
    }

    function calculateTaxFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_taxFee).div(10**2);
    }

    function calculateLiquidityFee(uint256 _amount)
        private
        view
        returns (uint256)
    {
        return _amount.mul(_liquidityFee).div(10**2);
    }

    function calculateBurnFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_burnFee).div(10**2);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        uint256 taxFee = calculateTaxFee(amount);
        uint256 liqFee = calculateLiquidityFee(amount);
        uint256 burnFee = calculateBurnFee(amount);
        uint256 transfAmount = amount - (taxFee + liqFee + burnFee);

        _balances[from] -= amount;
        _balances[to] += transfAmount;
        _balances[_owner] += taxFee;
        _balances[DEAD] += burnFee;
        accum_liq += liqFee;
        if (!inSwapAndLiquify && started && accum_liq > LACC) {
            swapAndLiquity(liqFee);
        }
        emit Transfer(from, to, _totalSupply);
    }

    function swapAndLiquity(uint256 contractTokenBalance) private lockTheSwap {
        uint256 half = contractTokenBalance.div(2);
        uint256 otherHalf = contractTokenBalance.sub(half);

        uint256 initialBalance = liqToken.balanceOf(address(this));

        swapTokensFor(half);

        uint256 newBalance = liqToken.balanceOf(address(this)).sub(
            initialBalance
        );

        // add liquidity to uniswap
        addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquity(half, newBalance, otherHalf);
    }

    function swapTokensFor(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = address(liqToken);

        _approve(address(this), address(router), tokenAmount);

        // make the swap
        router.swapExactTokensForTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function startLiquidity(uint256 tokenAmount, uint256 liqAmount) external {
        addLiquidity(tokenAmount, liqAmount);
        started = true;
    }

    function addLiquidity(uint256 tokenAmount, uint256 liqAmount) private {
        liqToken.approve(address(router), tokenAmount * 2);

        // add the liquidity
        router.addLiquidity(
            address(this),
            address(liqToken),
            tokenAmount,
            liqAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            _owner,
            block.timestamp
        );
    }
}
