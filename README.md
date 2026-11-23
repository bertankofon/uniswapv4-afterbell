# Afterbell

A Uniswap v4 hook that gives tokenized-equity pools curated, session-aware liquidity.

Tokenized stocks trade around the clock, but the quality of their reference price does not: it changes between
the regular session, extended hours, overnight, weekends, trading halts and the Monday reopen. A passive LP
quotes the same range and fee through all of it. Afterbell keeps the pool's liquidity in a hook-owned vault and
manages it by session, within bounds set by the venue:

- **Regular session:** tight range around the oracle price, low fee
- **Overnight / closed:** wider range, higher fee
- **Halt:** liquidity pulled, swaps refused
- **Reopen:** price moved to the oracle, liquidity re-centred, decaying surge fee

> Work in progress for the UHI11 Hookathon. See the status table below.

## Status

| Part | State |
|---|---|
| Hook skeleton: dynamic fee, one pool per hook, external liquidity blocked | done |
| Oracle interface (Chainlink Data Streams v11 report fields) | done |
| Mock oracle + session state machine | next |
| Vault (in-kind pro-rata shares) | planned |
| Oracle-centred rebalancing | planned |
| Halt / reopen | planned |
| Curator bounds, timelock, guardian | planned |
| Invariant tests, week-replay demo | planned |

## Build & test

```bash
git clone --recursive <repo-url>
forge test
```

## Partner integrations

No partner integrations. The oracle interface mirrors the field layout of Chainlink Data Streams v11 reports,
but the project runs against a mock oracle.

## Credits

- [OpenZeppelin Uniswap Hooks](https://github.com/OpenZeppelin/uniswap-hooks) (`BaseHook`)
- [Uniswap v4 core](https://github.com/Uniswap/v4-core) test utilities (`Deployers`)
