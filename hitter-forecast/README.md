# Forecasting Hitter Skills

**Andy Lucas** · R and Quarto · MLB hitter projections

This project forecasts next-season strikeout rate (K%), walk rate (BB%), and isolated power (ISO). It asks whether a hitter's longer track record improves forecasts beyond carrying his latest season—or his three-year weighted rate—forward unchanged.

The report combines model evaluation with baseball interpretation and a searchable table of 2027 projections, including model-based 80% prediction intervals.

## Main findings

History-based linear models won validation for all three targets. On the development-exposed 2026 evaluation sample of 300 hitters, they reduced MAE relative to the previous-season baseline by **10.0% for K%, 15.3% for BB%, and 18.2% for ISO**. They also beat the three-year weighted-rate benchmark, although the additional gains were small for K% and BB%. History models had lower pooled rolling-backtest MAE than the random forests for all three targets.

These are skill forecasts, not validated probabilities of an overall offensive breakout. Preliminary 2026 results were examined during development, so that season is not an untouched test.

## View the report

Read the [live report](https://andylucas13.github.io/hitter-forecast/hitter_breakout_forecast.html). You can also open `hitter_breakout_forecast.html` locally after downloading or cloning the repository. Keep `hitter_breakout_forecast_files/` beside it: that folder contains the figures, styling, and interactive-table dependencies. GitHub's file view shows HTML source rather than running the report.

## Skills demonstrated

- Downloading public API data and checking player-season records.
- Building calendar-year lags and count-weighted multi-season features.
- Reusing R functions for model fitting, scoring, and interval evaluation.
- Comparing regressions and random forests against two meaningful benchmarks.
- Evaluating chronologically with expanding-window historical backtests.
- Communicating baseball findings through plots, styled tables, and searchable projections.

## Repository files

| File | Purpose |
|---|---|
| `get_data.R` | Download and validate 2010–2026 regular-season batting totals |
| `hitter_breakout_forecast.qmd` | Feature preparation, models, evaluation, and report |
| `hitter_breakout_forecast.html` | Rendered report |
| `hitter_breakout_forecast_files/` | Required report assets |
| `data/batting_seasons.rds` | Saved input snapshot used by the report |
| `data/README.md` | Data source, fields, and snapshot details |

## Reproduce the analysis

1. Install R and Quarto. This analysis was run with R 4.5.1.
2. Open RStudio and set the working directory to this project's `hitter-forecast` folder, or start R from that folder.
3. Install the required packages:

```r
install.packages(c(
  "dplyr", "ggplot2", "kableExtra", "randomForest",
  "DT", "jsonlite", "knitr", "scales"))
```

4. Use the included data snapshot to reproduce the report. To intentionally refresh the data, run `source("get_data.R")`; this requires internet access and overwrites the snapshot. Updated API data may change the results.
5. Render the QMD in RStudio, or run `quarto render hitter_breakout_forecast.qmd` from a terminal in this folder. Historical backtests fit multiple random forests, so rendering can take several minutes.

Package versions used: dplyr 1.1.4, ggplot2 4.0.0, kableExtra 1.4.0, randomForest 4.7-1.2, DT 0.34.0, jsonlite 2.0.0, knitr 1.50, and scales 1.4.0. This lightweight portfolio folder does not enforce those versions automatically.

Rendering reads the saved data and does not download it. Only the downloader needs the MLB API.

## Evaluation design

Eligible pairs have at least 200 PA in the predictor season and 100 PA in the outcome season. Each pair counts equally in scoring. Training uses 2010–2022 predictor seasons; validation uses 2023–2024; the 2026 evaluation uses 2025 predictors. Rolling backtests forecast 2016–2025 using only earlier outcomes. Models are selected using validation MAE and refitted on completed pairs for 2027 projections.

## Limits

The analysis excludes hitters without sufficient returning playing time and does not predict playing time. Season totals omit contact quality, park adjustments, injuries, and mechanical changes. Prediction intervals assume common residual variance, are separate for each metric, and are not guarantees for individual players. The report discusses these limitations and the development history in detail.

## Data attribution

Batting totals come from the MLB Stats API. The included data documentation identifies the endpoint and processing steps. This is an independent portfolio analysis, with no MLB affiliation.
