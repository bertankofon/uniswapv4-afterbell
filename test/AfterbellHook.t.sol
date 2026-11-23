// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";

import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {LPFeeLibrary} from "v4-core/src/libraries/LPFeeLibrary.sol";
import {CustomRevert} from "v4-core/src/libraries/CustomRevert.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {ModifyLiquidityParams} from "v4-core/src/types/PoolOperation.sol";

import {AfterbellHook} from "../src/AfterbellHook.sol";

contract AfterbellHookTest is Test, Deployers {
    AfterbellHook hook;
    address oracle = makeAddr("oracle");

    uint160 constant FLAGS = uint160(
        Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
            | Hooks.BEFORE_SWAP_FLAG
    );

    function setUp() public {
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();

        // A hook's permissions are read from its address bits, so deploy straight to an address with FLAGS set.
        deployCodeTo("AfterbellHook.sol", abi.encode(manager, oracle), address(FLAGS));
        hook = AfterbellHook(address(FLAGS));
    }

    // ---------------------------------------------------------------------
    // Helpers
    // ---------------------------------------------------------------------

    function _initDynamicPool() internal {
        (key,) = initPool(currency0, currency1, hook, LPFeeLibrary.DYNAMIC_FEE_FLAG, SQRT_PRICE_1_1);
    }

    /// PoolManager wraps a hook's revert reason in CustomRevert.WrappedError.
    function _wrapped(bytes4 hookSelector, bytes4 reason) internal view returns (bytes memory) {
        return abi.encodeWithSelector(
            CustomRevert.WrappedError.selector,
            address(hook),
            hookSelector,
            abi.encodeWithSelector(reason),
            abi.encodeWithSelector(Hooks.HookCallFailed.selector)
        );
    }

    // ---------------------------------------------------------------------
    // Deployment & pool binding
    // ---------------------------------------------------------------------

    function test_storesOracle() public view {
        assertEq(address(hook.oracle()), oracle);
    }

    function test_bindsTheFirstDynamicFeePool() public {
        assertFalse(hook.isBound());
        _initDynamicPool();

        assertTrue(hook.isBound());
        (,, uint24 fee, int24 tickSpacing, IHooks hooks) = hook.poolKey();
        assertEq(fee, LPFeeLibrary.DYNAMIC_FEE_FLAG);
        assertEq(tickSpacing, key.tickSpacing);
        assertEq(address(hooks), address(hook));
    }

    function test_revertsOnStaticFeePool() public {
        vm.expectRevert(_wrapped(IHooks.beforeInitialize.selector, AfterbellHook.MustUseDynamicFee.selector));
        initPool(currency0, currency1, hook, 3000, SQRT_PRICE_1_1);
    }

    function test_revertsOnSecondPool() public {
        _initDynamicPool();

        // Same tokens, different tick spacing: a distinct pool that would try to share the hook's vault.
        PoolKey memory other = PoolKey(currency0, currency1, LPFeeLibrary.DYNAMIC_FEE_FLAG, 10, hook);
        vm.expectRevert(_wrapped(IHooks.beforeInitialize.selector, AfterbellHook.PoolAlreadyBound.selector));
        manager.initialize(other, SQRT_PRICE_1_1);
    }

    // ---------------------------------------------------------------------
    // Hook-owned liquidity
    // ---------------------------------------------------------------------

    function test_blocksExternalAddLiquidity() public {
        _initDynamicPool();

        vm.expectRevert(
            _wrapped(IHooks.beforeAddLiquidity.selector, AfterbellHook.ExternalLiquidityNotAllowed.selector)
        );
        modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);
    }

    function test_blocksExternalRemoveLiquidity() public {
        _initDynamicPool();

        vm.expectRevert(
            _wrapped(IHooks.beforeRemoveLiquidity.selector, AfterbellHook.ExternalLiquidityNotAllowed.selector)
        );
        modifyLiquidityRouter.modifyLiquidity(key, REMOVE_LIQUIDITY_PARAMS, ZERO_BYTES);
    }

    function testFuzz_blocksAnyExternalLiquidityChange(int24 lower, int24 upper, int128 delta) public {
        _initDynamicPool();
        vm.assume(delta != 0);
        lower = int24(bound(lower, -887220, 887100)) / 60 * 60;
        upper = int24(bound(upper, int256(lower) + 60, 887220)) / 60 * 60;
        vm.assume(upper > lower);

        ModifyLiquidityParams memory params =
            ModifyLiquidityParams({tickLower: lower, tickUpper: upper, liquidityDelta: delta, salt: bytes32(0)});
        bytes4 cb = delta > 0 ? IHooks.beforeAddLiquidity.selector : IHooks.beforeRemoveLiquidity.selector;

        vm.expectRevert(_wrapped(cb, AfterbellHook.ExternalLiquidityNotAllowed.selector));
        modifyLiquidityRouter.modifyLiquidity(key, params, ZERO_BYTES);
    }
}
