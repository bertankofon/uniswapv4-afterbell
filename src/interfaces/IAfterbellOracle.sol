// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title IAfterbellOracle
/// @notice Price source for an Afterbell pool. A report carries the fields of a Chainlink Data Streams
/// v11 (RWA / 24-5 US equities) report that Afterbell uses, so a verifier-backed adapter for a real
/// feed can be dropped in later without touching the hook.
/// @dev Prices are 18-decimal fixed point, quoted as token1 per token0, as in Data Streams reports.
interface IAfterbellOracle {
    /// @dev Values of `MarketReport.marketStatus`, as defined by the v11 schema.
    ///      The schema has no halt flag; halts reach Afterbell through a separate relay role.
    ///      0 Unknown · 1 Pre-market · 2 Regular · 3 Post-market · 4 Overnight · 5 Closed
    struct MarketReport {
        int192 mid; // mid price; can be 0 in thin overnight sessions
        int192 bid; // best bid
        int192 ask; // best ask
        uint64 lastSeenTimestampNs; // last time the provider saw a fresh quote (ns); not guaranteed monotonic
        uint32 marketStatus; // see above
        uint32 observationsTimestamp; // report timestamp (s)
        uint32 expiresAt; // report must not be used after this (s)
    }

    /// @notice The most recent report for this oracle's feed.
    function latestReport() external view returns (MarketReport memory);
}

/// @notice `marketStatus` values from the Chainlink Data Streams v11 schema.
library MarketStatus {
    uint32 internal constant UNKNOWN = 0;
    uint32 internal constant PRE_MARKET = 1;
    uint32 internal constant REGULAR = 2;
    uint32 internal constant POST_MARKET = 3;
    uint32 internal constant OVERNIGHT = 4;
    uint32 internal constant CLOSED = 5;
}
