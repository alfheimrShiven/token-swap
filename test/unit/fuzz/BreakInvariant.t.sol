// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Test} from "forge-std/Test.sol";
import {PoolFactory} from "../../../src/PoolFactory.sol";
import {TSwapPool} from "../../../src/TSwapPool.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {FuzzHandler} from "./FuzzHandler.t.sol";

contract BreakInvariant is StdInvariant, Test {
    PoolFactory poolFactory;
    TSwapPool pool;
    ERC20Mock poolToken;
    ERC20Mock wEth;
    address investor;
    uint256 constant STARTING_WETH_BAL = 50e18;
    uint256 constant STARTING_POOLTOKEN_BAL = 100e18;
    FuzzHandler fuzzHandler;

    function setUp() external {
        poolToken = new ERC20Mock();
        wEth = new ERC20Mock();
        poolFactory = new PoolFactory(address(wEth));
        pool = TSwapPool(poolFactory.createPool(address(poolToken)));

        // warming up the pool with the initial deposit, setting the ratio of poolToken:wEth = 2:1
        poolToken.mint(address(this), STARTING_POOLTOKEN_BAL);
        wEth.mint(address(this), STARTING_WETH_BAL);

        poolToken.approve(address(pool), type(uint256).max);
        wEth.approve(address(pool), type(uint256).max);

        pool.deposit(
            STARTING_WETH_BAL,
            STARTING_WETH_BAL,
            STARTING_POOLTOKEN_BAL,
            uint64(block.timestamp)
        );

        fuzzHandler = new FuzzHandler(pool);
        bytes4[] memory selectors = new bytes4[](2);

        selectors[0] = fuzzHandler.deposit.selector;
        selectors[1] = fuzzHandler
            .swapPoolTokenForWEthBasedOnOutputWEth
            .selector;

        targetSelector(
            FuzzSelector({addr: address(fuzzHandler), selectors: selectors})
        );

        targetContract(address(fuzzHandler));
    }

    function statefulFuzz_ProductMarketMakerConstantRemainsSame() public {
        assertEq(
            fuzzHandler.actualDeltaWEth(),
            fuzzHandler.expectedDeltaWEth()
        );
    }
}
