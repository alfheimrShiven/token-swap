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

    constructor(TSwapPool _pool) {
        pool = _pool;
        wEth = ERC20Mock(pool.getWeth);
        poolToken = ERC20Mock(pool.getPoolToken);
    }

    function deposit(uint256 wEthAmt) public {
        int256 startingWEthAmt = wEth.balanceOf(address(pool));
        int256 startingPoolTokenAmt = poolToken.balanceOf(address(pool));

        bound(wEthAmt, 0, type(uint64).max);
        uint256 expectedDeltaWEth = wEthAmt;
        uint256 expectedDeltaPoolToken = pool.getPoolTokensToDepositBasedOnWeth(
            wEthAmt
        );

        // deposit
        vm.startPrank(liquidityProvider);
        wEth.mint(liquidityProvider, expectedDeltaWEth);
        poolToken.mint(liquidityProvider, expectedDeltaPoolToken);

        wEth.approve(address(this), type(uint64).max);
        poolToken.approve(address(this), type(uint64).max);

        pool.deposit(
            expectedDeltaWEth,
            0,
            expectedDeltaPoolToken,
            uint64(block.timestamp())
        );
        vm.stopPrank();
    }
}
