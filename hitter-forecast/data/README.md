# Data snapshot

Source: MLB Stats API, regular-season MLB batting totals.

Endpoint pattern:

```text
https://statsapi.mlb.com/api/v1/stats?stats=season&group=hitting&season=YEAR&sportIds=1&playerPool=ALL&limit=10000&gameType=R
```

`get_data.R` requests 2010–2026, retains records with positive PA, computes rate statistics, checks duplicate player-season keys and plausible values, and saves `batting_seasons.rds`.

## Snapshot provenance

- Coverage: 2010–2026; 14,569 player-season records.
- Repository packaging date: October 3, 2026.
- Original API retrieval timestamp: not recorded by the existing downloader. The packaging date should not be interpreted as the retrieval date.
- SHA-256: `4cb7725c7bc8e80bbff4d4fd0e497ec68b58e5f4a6f30e2b61ea84fe2f701725`.

The included file preserves the input snapshot for this report. Refreshing the downloader can change historical totals or the latest season; preserve the snapshot if comparing results across versions.

## Fields

| Fields | Meaning |
|---|---|
| `player_id`, `player_name` | MLB player identifier and display name |
| `season`, `age` | Season and age supplied by the API |
| `pa`, `at_bats` | Plate appearances and at-bats |
| `strikeouts`, `walks` | Strikeout and walk counts |
| `doubles`, `triples`, `home_runs` | Extra-base hit counts |
| `k_rate` | Strikeouts divided by PA |
| `bb_rate` | Walks divided by PA |
| `iso` | (Doubles + 2 × triples + 3 × home runs) divided by at-bats |

The QMD builds all history features and next-season targets from this snapshot. Missing calendar years are not treated as consecutive seasons. Model eligibility and chronological splits are described in the report and root README.

Public accessibility is not a grant of ownership over MLB data. No license to the underlying data is asserted by this repository.
