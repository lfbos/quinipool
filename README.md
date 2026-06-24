# QuiniPool

On-chain soccer prediction pool. Players pay an ERC20 entry fee, predict
scores for a fixed list of matches, and split the pot based on a points
leaderboard.

## Flow

1. **Deploy** — owner sets the token, entry fee, and the list of matches (home/away/kickoff).
2. **Open** — players call `joinPool()` (pays `entryFee`).
3. **Active** — owner calls `startPool()` (requires ≥ 2 players). Players submit predictions via `submitPrediction(matchId, homeScore, awayScore)` before each kickoff.
4. **Results** — owner calls `setMatchResult(matchId, homeScore, awayScore)` for each match.
5. **Finished** — owner calls `finishPool()` once all results are set.
6. **Claim** — top-3 players call `claimPrize()` to withdraw their share.

## Scoring

Per match, against each player's prediction:

| Case | Points |
|---|---|
| Exact score | 10 |
| Correct 1X2 outcome only | 4 |
| Wrong outcome / no prediction | 0 |

`calculatePoints(address)` is `view` — call it free off-chain at any time.

## Prizes

Split by leaderboard position (distinct scores, sports-ranking style):

| Position | Share |
|---|---|
| 1st | 50% |
| 2nd | 30% |
| 3rd | 20% |

Ties at the same position split that position's share evenly. Lower
positions are not shifted. Tie dust (rounding) stays in the contract.

## Commands

All workflows are wrapped in the `Makefile`. Run `make help` for the full list. Most used:

```bash
make install        # fetch git submodules (OpenZeppelin, forge-std)
make build          # compile
make test           # run all tests (verbose)
make coverage       # HTML coverage report, opens in browser
make fmt            # format
```

Current coverage: 100% lines / statements / branches / funcs.
