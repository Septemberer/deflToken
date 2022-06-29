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
import "hardhat/console.sol";

contract dfERC20 is ERC20, Ownable {
    using Address for address;
    using SafeMath for uint256;

    mapping(address => bool) private _withoutFee;
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;
    uint256 private constant LACC = 1 * 10**18;
    uint256 private accum_liq;

    string private _name = "DeFLateToken";
    string private _symbol = "DFLT";
    uint8 private _decimals = 18;
    bool private started = true;

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
        uint256 totSup = 42000000 * 10**18;

        _mint(_msgSender(), totSup);

        router = _router;

        _withoutFee[_msgSender()] = true;
        _withoutFee[address(router)] = true;

        emit Transfer(address(0), _msgSender(), totSup);

        _afterTokenTransfer(address(0), _msgSender(), totSup);
    }

    function transfer(address to, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    function allowance(address owner, address spender)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function swapAndLiquity(uint256 contractTokenBalance) private lockTheSwap {
        uint256 half = contractTokenBalance.div(2);
        uint256 otherHalf = contractTokenBalance.sub(half);

        uint256 initialBalance = liqToken.balanceOf(address(this));

        swapTokensFor(half);

        uint256 newBalance = liqToken.balanceOf(address(this)).sub(
            initialBalance
        );
        console.log("swap");
        // add liquidity to uniswap
        addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquity(half, newBalance, otherHalf);
    }

    function swapTokensFor(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(liqToken);
        path[1] = address(this);

        liqToken.approve(address(router), tokenAmount);

        // make the swap
        router.swapExactTokensForTokens(
            tokenAmount,
            0,
            path,
            _owner,
            block.timestamp
        );
        console.log("swap");
        unchecked {
            _totalSupply -= tokenAmount;
        }
    }

    function startLiquidity(uint256 tokenAmount, uint256 liqAmount)
        external
        onlyOwner
    {
        started = true;
        addLiquidity(tokenAmount, liqAmount);
    }

    function addLiquidity(uint256 tokenAmount, uint256 liqAmount) private {
        liqToken.approve(address(router), liqAmount);
        approve(address(router), tokenAmount);

        // add the liquidity
        router.addLiquidity(
            address(liqToken),
            address(this),
            liqAmount,
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            _owner,
            block.timestamp
        );
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
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
        require(to != address(0), "ERC20: transfer to the zero address");
        require(started, "not started");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(
            fromBalance >= amount,
            "ERC20: transfer amount exceeds balance"
        );
        if (!_withoutFee[from]) {
            uint256 taxFee = calculateTaxFee(amount);
            uint256 liqFee = calculateLiquidityFee(amount);
            uint256 burnFee = calculateBurnFee(amount);
            uint256 transfAmount = amount - (taxFee + liqFee + burnFee);

            unchecked {
                _balances[from] = fromBalance - amount;
            }

            _balances[to] += transfAmount;
            _balances[_owner] += taxFee;
            _balances[DEAD] += burnFee;
            unchecked {
                _totalSupply -= burnFee;
            }
            accum_liq += liqFee;

            if (accum_liq > LACC && !inSwapAndLiquify && started) {
                accum_liq = 0;
                swapAndLiquity(LACC);
            }
        } else {
            unchecked {
                _balances[from] = fromBalance - amount;
            }
            _balances[to] += amount;
        }
        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    function _mint(address account, uint256 amount) internal override {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal override {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal override {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal override {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(
                currentAllowance >= amount,
                "ERC20: insufficient allowance"
            );
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }
}
