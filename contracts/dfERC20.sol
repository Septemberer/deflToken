// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./resources/pancake-swap/interfaces/IPancakeRouter02.sol";
import "./resources/pancake-swap/interfaces/IPancakeFactory.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "./resources/LandS.sol";

contract dfERC20 is ERC20, Ownable {
    using Address for address;
    using SafeMath for uint256;

    mapping(address => bool) private _withoutFee;

    uint256 private constant LACC = 1 * 10**18;
    uint256 private accum_liq;

    string private _name = "DeFLateToken";
    string private _symbol = "DFLT";
    uint8 private _decimals = 18;

    uint256 private _taxFee = 2;
    address private immutable _owner;

    uint256 private _liquidityFee = 2;

    uint256 private _burnFee = 1;
    address private constant DEAD = 0x000000000000000000000000000000000000dEaD;

    IPancakeRouter02 public router;
    address public pancakePair;

    IERC20Metadata public immutable liqToken;
    bool private inSwapAndLiquify;
    bool private LandSAdded;
    LandS private liq;

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
        _withoutFee[address(this)] = true;

        emit Transfer(address(0), _msgSender(), totSup);

        _afterTokenTransfer(address(0), _msgSender(), totSup);
    }

    function setLandS(uint256 amount) external lockTheSwap onlyOwner {
        require(!LandSAdded, "LandS Added");
        LandSAdded = true;
        liq = new LandS(liqToken, this, router, _owner);
        _withoutFee[address(liq)] = true;
        liqToken.transfer(address(liq), amount);
        _transfer(address(this), address(liq), amount);
        liq.startLiquidity(amount);
        address pair = IPancakeFactory(router.factory()).getPair(
            address(liqToken),
            address(this)
        );
        _withoutFee[pair] = true;
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

    function getLiqAdr() public view returns (address) {
        return address(liq);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        uint256 fromBalance = balanceOf(from);
        require(
            fromBalance >= amount,
            "ERC20: transfer amount exceeds balance"
        );

        if (
            !_withoutFee[from] &&
            !_withoutFee[to] &&
            !inSwapAndLiquify &&
            LandSAdded
        ) {
            require(liq.getStart(), "not started");
            uint256 taxFee = calculateTaxFee(amount);
            uint256 liqFee = calculateLiquidityFee(amount);
            uint256 burnFee = calculateBurnFee(amount);
            uint256 transfAmount = amount - (taxFee + liqFee + burnFee);

            super._transfer(from, to, transfAmount);
            super._transfer(from, _owner, taxFee);
            super._transfer(from, DEAD, burnFee);
            super._transfer(from, address(liq), liqFee);

            _burn(_owner, burnFee);

            accum_liq += liqFee;

            if (accum_liq > LACC && liq.getStart()) {
                liqToken.approve(address(liq), accum_liq);
                _approve(address(this), address(liq), accum_liq);
                inSwapAndLiquify = true;
                uint256 liqsub = liq.swapAndLiquity(accum_liq);
                inSwapAndLiquify = false;
                _burn(_owner, liqsub);
                accum_liq = 0;
            }
        } else {
            super._transfer(from, to, amount);
        }
        emit Transfer(from, to, amount);
    }
}
