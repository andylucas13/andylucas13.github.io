# Power 4 Bullpen Matchup Calculator

An interactive R Shiny application that ranks bullpen options against an opposing hitter or lineup using NCAA TrackMan pitch-by-pitch data.

The model represents each pitcher's current arsenal by pitch family, shape, and usage. It then searches a hitter's history for comparable pitches and estimates context-neutral run value per 100 pitches (RV/100). Lower values favor the pitcher.

## Features

- Searchable bullpen and opposing-team selectors
- Team-filtered 2026 hitter rosters
- Lineup analysis for up to nine hitters
- Pitcher rankings with similarity coverage
- Pitch-family detail with whiff rate, hard-hit rate, and wOBA
- Downloadable rankings, pitcher detail, and matchup matrices
- Temporal validation using held-out 2026 games

## Modeling approach

Pitch similarity is calculated from standardized:

- Release speed
- Induced vertical break
- Horizontal break
- Spin rate
- Release height
- Release side

The default Euclidean-distance threshold is 1.50. Hitter results against similar pitches are shrunk toward pitcher-hand and pitch-family league averages to reduce small-sample volatility. The model uses 2025 as its historical foundation, gives early-2026 results additional weight, and uses later 2026 games for validation.

## Project files

- `ui.R` — Shiny interface and page layout
- `server.R` — reactive calculations, visualizations, tables, and downloads
- `global.R` — configuration and shared model initialization
- `model_backend.R` — cleaning, feature engineering, run values, similarity model, and bullpen ranking
- `bullpen_matchup_report.qmd` — methodology and validation report that renders to standalone HTML

## Run locally

Install the required R packages:

```r
install.packages(c(
  "data.table", "dplyr", "tidyr", "ggplot2", "knitr",
  "lubridate", "stringr", "shiny", "DT"))
```

Set the two TrackMan file paths in `global.R` and in the QMD parameters. From the project directory, run:

```r
shiny::runApp(".")
```

## Interpretation

`ProjectedRV100` estimates the hitter's context-neutral runs created per 100 pitches against the selected pitcher's usage-weighted arsenal. Lower values indicate a more favorable matchup for the pitcher.

`SimilarityCoverage` reports how much of the pitcher's arsenal has an adequate historical comparison sample. Low-coverage recommendations should be treated cautiously.

This is a matchup and scouting tool rather than a claim of causal pitcher performance. Individual-pitch outcomes are noisy, and the model is most useful for comparing bullpen options under the same settings.

## Data availability

The underlying TrackMan data is proprietary and is intentionally excluded. The repository contains the analysis and application code but no raw player-level data.
