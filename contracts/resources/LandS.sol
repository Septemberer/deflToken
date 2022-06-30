// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./pancake-swap/interfaces/IPancakeRouter02.sol";
import "./pancake-swap/interfaces/IPancakePair.sol";
import "./pancake-swap/interfaces/IPancakeFactory.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract LandS is Ownable {
    using Address for address;
    using SafeMath for uint256;

    IPancakeRouter02 public immutable router;
    IERC20 public immutable tokenA;
    IERC20 public immutable tokenB;

    bool private inSwapAndLiquify;
    bool private started;

    address private immutable _owner;

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

    constructor(
        IERC20 _tokenA,
        IERC20 _tokenB,
        IPancakeRouter02 _router,
        address owner_
    ) {
        tokenA = _tokenA;
        tokenB = _tokenB;
        router = _router;
        _owner = owner_;
    }

    function swapAndLiquity(uint256 contractTokenBalance)
        public
        lockTheSwap
        returns (uint256 half)
    {
        half = contractTokenBalance.div(2);
        uint256 otherHalf = contractTokenBalance.sub(half);

        uint256 initialBalance = tokenA.balanceOf(address(this));
        swapTokensFor(half);
        uint256 newBalance = tokenA.balanceOf(address(this)).sub(
            initialBalance
        );
        // add liquidity to uniswap
        addLiquidity(otherHalf, newBalance);
        emit SwapAndLiquity(half, newBalance, otherHalf);
    }

    function swapTokensFor(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(tokenB);
        path[1] = address(tokenA);

        tokenB.approve(address(router), tokenAmount);

        // make the swap
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function getStart() public view returns (bool) {
        return started;
    }

    function startLiquidity(uint256 tokenAmount) external onlyOwner {
        require(!started, "Started");
        started = true;
        addLiquidity(tokenAmount, tokenAmount);
    }

    function addLiquidity(uint256 tokenAmount, uint256 liqAmount) private {
        tokenA.approve(address(router), liqAmount);
        tokenB.approve(address(router), tokenAmount);
        // add the liquidity
        router.addLiquidity(
            address(tokenA),
            address(tokenB),
            tokenAmount,
            liqAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(this),
            block.timestamp
        );
    }
}
