// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseHook} from "@openzeppelin/uniswap-hooks/src/base/BaseHook.sol";

import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {LPFeeLibrary} from "v4-core/src/libraries/LPFeeLibrary.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/src/types/PoolOperation.sol";

import {IAfterbellOracle} from "./interfaces/IAfterbellOracle.sol";

/// @title AfterbellHook
/// @notice Session-aware, curator-managed liquidity for a tokenized-equity pool.
/// @dev Day-1 skeleton. One hook instance manages exactly one pool. All liquidity in that pool is owned by
/// the hook: outside callers cannot add or remove liquidity directly and will instead go through the vault.
/// The PoolManager skips a hook's own callbacks when the hook itself modifies liquidity
/// (Hooks.sol `noSelfCall`), so the reverts below block outsiders only.
contract AfterbellHook is BaseHook {
    using LPFeeLibrary for uint24;
    using PoolIdLibrary for PoolKey;

    error MustUseDynamicFee();
    error PoolAlreadyBound();
    error ExternalLiquidityNotAllowed();

    event PoolBound(PoolId indexed poolId);

    /// @dev Fees are in pips (1_000_000 = 100%). Flat placeholder until session-based fees are added.
    uint24 public constant BASE_FEE = 3000;

    IAfterbellOracle public immutable oracle;

    /// @notice The single pool this hook manages. Set once, when that pool is initialized.
    PoolKey public poolKey;
    bool public isBound;

    constructor(IPoolManager _poolManager, IAfterbellOracle _oracle) BaseHook(_poolManager) {
        oracle = _oracle;
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true,
            afterInitialize: false,
            beforeAddLiquidity: true,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: true,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    /// @dev The fee must be set per swap, so a static-fee pool is refused. The first pool initialized with this
    /// hook becomes its pool; any later one is refused, since the vault's shares describe a single position.
    function _beforeInitialize(address, PoolKey calldata key, uint160) internal override returns (bytes4) {
        if (!key.fee.isDynamicFee()) revert MustUseDynamicFee();
        if (isBound) revert PoolAlreadyBound();
        poolKey = key;
        isBound = true;
        emit PoolBound(key.toId());
        return this.beforeInitialize.selector;
    }

    function _beforeAddLiquidity(address, PoolKey calldata, ModifyLiquidityParams calldata, bytes calldata)
        internal
        pure
        override
        returns (bytes4)
    {
        revert ExternalLiquidityNotAllowed();
    }

    function _beforeRemoveLiquidity(address, PoolKey calldata, ModifyLiquidityParams calldata, bytes calldata)
        internal
        pure
        override
        returns (bytes4)
    {
        revert ExternalLiquidityNotAllowed();
    }

    function _beforeSwap(address, PoolKey calldata, SwapParams calldata, bytes calldata)
        internal
        pure
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        // OVERRIDE_FEE_FLAG tells the PoolManager to use this fee for this swap only.
        return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, BASE_FEE | LPFeeLibrary.OVERRIDE_FEE_FLAG);
    }
}
