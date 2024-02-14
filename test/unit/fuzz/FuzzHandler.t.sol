// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Test} from "forge-std/Test.sol";
import {TSwapPool} from "../../../src/TSwapPool.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract FuzzHandler is Test {
    TSwapPool pool;
    ERC20Mock wEth;
    ERC20Mock poolToken;
    address liquidityProvider = makeAddr("lp");
    address swapper = makeAddr("swapper");

    int256 public startingWEthAmt;
    int256 public startingPoolTokenAmt;

    // the changes in token composition being introduced (will be compared with actualDelta values)
    int256 public expectedDeltaPoolToken;
    int256 public expectedDeltaWEth;

    // the actual changes in token composition that happened (will be compared with expectedDelta values)
    int256 public actualDeltaPoolToken;
    int256 public actualDeltaWEth;

    constructor(TSwapPool _pool) {
        pool = _pool;
        wEth = ERC20Mock(pool.getWeth());
        poolToken = ERC20Mock(pool.getPoolToken());
    }

    function deposit(uint256 wEthAmt) public {
        wEthAmt = bound(
            wEthAmt,
            pool.getMinimumWethDepositAmount(),
            type(uint64).max
        );

        startingWEthAmt = int256(wEth.balanceOf(address(pool)));
        startingPoolTokenAmt = int256(poolToken.balanceOf(address(pool)));

        // changes in token composition being introduced
        expectedDeltaWEth = int256(wEthAmt);
        expectedDeltaPoolToken = int256(
            pool.getPoolTokensToDepositBasedOnWeth(wEthAmt)
        );

        // deposit
        vm.startPrank(liquidityProvider);
        wEth.mint(liquidityProvider, uint256(expectedDeltaWEth));
        poolToken.mint(liquidityProvider, uint256(expectedDeltaPoolToken));

        wEth.approve(address(pool), type(uint64).max);
        poolToken.approve(address(pool), uint256(expectedDeltaPoolToken) + 1);

        pool.deposit(
            uint256(expectedDeltaWEth),
            0,
            uint256(expectedDeltaPoolToken),
            uint64(block.timestamp)
        );
        vm.stopPrank();

        // updating the actual deltas
        uint256 endingWEth = wEth.balanceOf(address(pool));
        uint256 endingPoolToken = poolToken.balanceOf(address(pool));

        actualDeltaPoolToken =
            int256(endingPoolToken) -
            int256(startingPoolTokenAmt);
        actualDeltaWEth = int256(endingWEth) - int256(startingWEthAmt);
    }

    function swapPoolTokenForWEthBasedOnOutputWEth(uint256 outputWEth) public {
        outputWEth = bound(
            outputWEth,
            pool.getMinimumWethDepositAmount(),
            wEth.balanceOf(address(pool))
        );

        uint256 poolTokenAmount = pool.getInputAmountBasedOnOutput(
            outputWEth,
            poolToken.balanceOf(address(pool)),
            wEth.balanceOf(address(pool))
        );

        if (poolTokenAmount > type(uint64).max) {
            return;
        }

        startingWEthAmt = int256(wEth.balanceOf(address(pool)));
        startingPoolTokenAmt = int256(poolToken.balanceOf(address(pool)));

        // the changes being introduced
        expectedDeltaWEth = int256(-1) * int256(outputWEth); // deduction
        expectedDeltaPoolToken = int256(poolTokenAmount);

        if (poolTokenAmount > poolToken.balanceOf(swapper)) {
            poolToken.mint(
                swapper,
                (poolTokenAmount - poolToken.balanceOf(swapper)) + 1
            );
        }

        vm.startPrank(swapper);
        poolToken.approve(address(pool), type(uint64).max);
        pool.swapExactOutput(
            poolToken,
            wEth,
            outputWEth,
            uint64(block.timestamp)
        );
        vm.stopPrank();

        // updating ending deltas
        uint256 endingWEth = wEth.balanceOf(address(pool));
        uint256 endingPoolToken = poolToken.balanceOf(address(pool));

        actualDeltaPoolToken =
            int256(endingPoolToken) -
            int256(startingPoolTokenAmt);
        actualDeltaWEth = int256(endingWEth) - int256(startingWEthAmt); // will be negative since this represents deduction
    }
}
