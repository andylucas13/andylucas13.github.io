# Shared model backend for the standalone Shiny application.
# `params` must be defined before this file is sourced.

# ---- setup ----
library(data.table)
library(dplyr)
library(tidyr)
library(ggplot2)
library(knitr)
library(lubridate)
library(stringr)
library(shiny)
library(DT)

if (!exists("params")) {
  params <- list(
    validation_start = "2026-04-15",
    similarity_threshold = 1.50,
    similarity_thresholds_to_test = c(1.00, 1.50, 2.00),
    validation_sample_n = 2500,
    shrinkage_pitches = 50,
    weight_2025 = 1,
    weight_2026 = 2,
    minimum_similar_pitches = 25,
    minimum_pitcher_pitches = 50,
    minimum_matchup_coverage = 0.50)}

set.seed(42)
path_2025 <- params$data_path_2025
path_2026 <- params$data_path_2026
validation_start <- as.Date(params$validation_start)

if (!file.exists(path_2025) || !file.exists(path_2026)) {
  stop("Set data_path_2025 and data_path_2026 in the document parameters before rendering.")}

# Attributes the hitter can perceive. Location is retained for reporting only.
similarity_features <- c(
  "RelSpeed", "InducedVertBreak", "HorzBreak",
  "SpinRate", "RelHeight", "RelSide")

# ---- read-data ----
required_columns <- c(
  "Date", "Season", "Pitcher", "PitcherTeam", "PitcherThrows",
  "Batter", "BatterTeam", "BatterSide", "TaggedPitchType",
  "AutoPitchType", "PitchCall", "PlayResult", "KorBB", "Balls",
  "Strikes", "RelSpeed", "SpinRate", "RelHeight", "RelSide",
  "Extension", "InducedVertBreak", "HorzBreak", "PlateLocHeight",
  "PlateLocSide", "ExitSpeed", "Angle", "HomeTeam", "AwayTeam",
  "TopBottom", "GameID", "PlayID")

read_trackman <- function(path, season_label) {
  available <- names(fread(path, nrows = 0, showProgress = FALSE))
  missing <- setdiff(required_columns, available)
  if (length(missing) > 0) {
    stop("Missing required columns in ", path, ": ", paste(missing, collapse = ", "))}
  fread(
    path, select = required_columns, showProgress = TRUE,
    na.strings = c("", "NA", "NaN", "null")
  ) %>% mutate(SourceSeason = season_label)}

raw_2025 <- read_trackman(path_2025, 2025L)
raw_2026 <- read_trackman(path_2026, 2026L)

# ---- preparation-functions ----
normalize_player <- function(x) {
  x %>% str_to_lower() %>% str_replace_all("[^a-z0-9]+", " ") %>% str_squish()}

pitch_family <- function(tagged, auto) {
  pitch <- if_else(is.na(tagged) | tagged %in% c("Undefined", "Other"), auto, tagged)
  pitch <- str_to_lower(coalesce(pitch, "undefined"))
  case_when(
    pitch %in% c("fastball", "fast ball", "fourseamfastball", "four-seam") ~ "Four-seam",
    pitch %in% c("sinker", "twoseamfastball", "oneseamfastball", "two-seam") ~ "Sinker",
    pitch %in% c("slider", "cutter", "sweeper") ~ "Slider/Cutter",
    pitch %in% c("curveball", "curve", "knuckle curve") ~ "Curveball",
    pitch %in% c("changeup", "change up", "splitter", "split-finger") ~ "Offspeed",
    TRUE ~ NA_character_)}

prepare_trackman <- function(df) {
  df %>% mutate(
    GameDate = as.Date(ymd_hms(Date, quiet = TRUE, tz = "UTC")),
    PitcherKey = normalize_player(Pitcher),
    BatterKey = normalize_player(Batter),
    PitchFamily = pitch_family(TaggedPitchType, AutoPitchType),
    PitcherThrows = case_when(
      str_to_lower(PitcherThrows) == "right" ~ "R",
      str_to_lower(PitcherThrows) == "left" ~ "L",
      TRUE ~ NA_character_),
    BatterSide = case_when(
      str_to_lower(BatterSide) == "right" ~ "R",
      str_to_lower(BatterSide) == "left" ~ "L",
      TRUE ~ NA_character_),
    Balls = as.integer(Balls),
    Strikes = as.integer(Strikes),
    RecencyWeight = if_else(SourceSeason == 2026L, params$weight_2026, params$weight_2025))}

clean_trackman <- function(df) {
  df %>% filter(
    !is.na(PitcherKey), PitcherKey != "", !is.na(BatterKey), BatterKey != "",
    !is.na(PitcherThrows), !is.na(BatterSide), !is.na(PitchCall), !is.na(PitchFamily),
    if_all(all_of(similarity_features), ~ !is.na(.x)),
    between(Balls, 0, 3), between(Strikes, 0, 2),
    between(RelSpeed, 55, 105), between(SpinRate, 500, 4000),
    between(RelHeight, 2, 8), between(RelSide, -5, 5),
    between(InducedVertBreak, -35, 35), between(HorzBreak, -35, 35),
    PitchCall %in% c(
      "StrikeSwinging", "StrikeCalled", "Strikecalled", "AutomaticStrike",
      "FoulBallNotFieldable", "FoulBallFieldable", "FoulBall",
      "BallCalled", "BallinDirt", "AutomaticBall", "BallIntentional",
      "BallIntentional ", "HitByPitch", "InPlay"))}

prepared_2025 <- prepare_trackman(raw_2025)
prepared_2026 <- prepare_trackman(raw_2026)
clean_2025 <- clean_trackman(prepared_2025)
clean_2026 <- clean_trackman(prepared_2026)

quality_summary <- tibble(
  Season = c(2025, 2026),
  RawRows = c(nrow(raw_2025), nrow(raw_2026)),
  ModelRows = c(nrow(clean_2025), nrow(clean_2026))
) %>% mutate(ExcludedRows = RawRows - ModelRows, ModelRowPct = ModelRows / RawRows)
kable(quality_summary, digits = 3)

# ---- run-value-functions ----
add_transitions <- function(df) {
  ball_call <- df$PitchCall %in% c(
    "BallCalled", "BallinDirt", "AutomaticBall", "BallIntentional", "BallIntentional ")
  strike_call <- df$PitchCall %in% c(
    "StrikeSwinging", "StrikeCalled", "Strikecalled", "AutomaticStrike")
  foul_call <- df$PitchCall %in% c(
    "FoulBallNotFieldable", "FoulBallFieldable", "FoulBall")
  walk <- df$KorBB == "Walk" | df$PitchCall %in% c("BallIntentional", "BallIntentional ") |
    (ball_call & df$Balls == 3)
  strikeout <- df$KorBB == "Strikeout" | (strike_call & df$Strikes == 2)
  hbp <- df$PitchCall == "HitByPitch"
  in_play <- df$PitchCall == "InPlay"
  terminal <- walk | strikeout | hbp | in_play

  terminal_value <- case_when(
    walk | hbp ~ 0.33,
    in_play & df$PlayResult %in% c("Single", "Single ", "Error") ~ 0.47,
    in_play & df$PlayResult == "Double" ~ 0.78,
    in_play & df$PlayResult == "Triple" ~ 1.09,
    in_play & df$PlayResult == "HomeRun" ~ 1.40,
    TRUE ~ 0)
  woba_value <- case_when(
    walk | hbp ~ 0.70,
    in_play & df$PlayResult %in% c("Single", "Single ", "Error") ~ 0.90,
    in_play & df$PlayResult == "Double" ~ 1.25,
    in_play & df$PlayResult == "Triple" ~ 1.60,
    in_play & df$PlayResult == "HomeRun" ~ 2.00,
    TRUE ~ 0)

  next_balls <- df$Balls
  next_strikes <- df$Strikes
  next_balls[ball_call & !terminal] <- next_balls[ball_call & !terminal] + 1L
  next_strikes[strike_call & !terminal] <- next_strikes[strike_call & !terminal] + 1L
  next_strikes[foul_call & df$Strikes < 2 & !terminal] <-
    next_strikes[foul_call & df$Strikes < 2 & !terminal] + 1L

  df %>% mutate(
    State = paste0(Balls, "-", Strikes),
    IsTerminal = terminal,
    TerminalValue = terminal_value,
    NextState = if_else(terminal, NA_character_, paste0(next_balls, "-", next_strikes)),
    IsSwing = PitchCall %in% c(
      "StrikeSwinging", "FoulBallNotFieldable", "FoulBallFieldable", "FoulBall", "InPlay"),
    IsWhiff = PitchCall == "StrikeSwinging",
    IsBIP = in_play,
    IsHardHit = in_play & !is.na(ExitSpeed) & ExitSpeed >= 95,
    IsPAEnd = terminal,
    WOBAValue = woba_value)}

estimate_count_values <- function(df, tolerance = 1e-10, max_iter = 1000) {
  states <- as.vector(outer(0:3, 0:2, paste, sep = "-"))
  values <- setNames(rep(0.30, length(states)), states)
  for (iteration in seq_len(max_iter)) {
    continuation <- values[df$NextState]
    target <- ifelse(df$IsTerminal, df$TerminalValue, continuation)
    estimates <- tibble(State = df$State, Target = target) %>%
      group_by(State) %>% summarise(Value = mean(Target, na.rm = TRUE), .groups = "drop")
    updated <- values
    updated[estimates$State] <- estimates$Value
    if (max(abs(updated - values), na.rm = TRUE) < tolerance) {
      values <- updated
      break
    }
    values <- updated
  }
  values
}

development_2026_dates <- clean_2026 %>% filter(GameDate < validation_start)
development_base <- bind_rows(clean_2025, development_2026_dates) %>% add_transitions()
validation_base <- clean_2026 %>% filter(GameDate >= validation_start) %>% add_transitions()
count_values <- estimate_count_values(development_base)

add_pitch_rv <- function(df, values) {
  resulting_value <- ifelse(df$IsTerminal, df$TerminalValue, values[df$NextState])
  df %>% mutate(PitchRV = resulting_value - values[State])}

development_base <- add_pitch_rv(development_base, count_values)
validation_base <- add_pitch_rv(validation_base, count_values)
count_value_table <- tibble(Count = names(count_values), ExpectedRuns = as.numeric(count_values)) %>%
  arrange(Count)
kable(count_value_table, digits = 3)

# ---- standardize-features ----
training_2025 <- development_base %>% filter(SourceSeason == 2025)
feature_center <- vapply(
  as.data.frame(training_2025)[, similarity_features, drop = FALSE],
  mean, numeric(1), na.rm = TRUE)
feature_scale <- vapply(
  as.data.frame(training_2025)[, similarity_features, drop = FALSE],
  sd, numeric(1), na.rm = TRUE)
feature_scale[!is.finite(feature_scale) | feature_scale == 0] <- 1

standardize_shapes <- function(df) {
  output <- df
  for (feature in similarity_features) {
    output[[paste0("Z_", feature)]] <-
      (output[[feature]] - feature_center[[feature]]) / feature_scale[[feature]]}
  output}

z_features <- paste0("Z_", similarity_features)
development <- standardize_shapes(development_base)
validation <- standardize_shapes(validation_base)
current_arsenal_data <- standardize_shapes(add_pitch_rv(add_transitions(clean_2026), count_values))

# The app offers only hitters who appear in 2026. Normalize spelling and retain
# the most recently observed 2026 team for a clear, unique selector label.
hitter_directory <- clean_2026 %>%
  filter(!is.na(BatterKey), BatterKey != "", !is.na(Batter), Batter != "") %>%
  arrange(BatterKey, desc(GameDate), desc(!is.na(BatterTeam) & BatterTeam != "")) %>%
  group_by(BatterKey) %>%
  summarise(
    Batter = str_squish(first(Batter)),
    CurrentTeam = first(BatterTeam[!is.na(BatterTeam) & BatterTeam != ""], default = "Unknown"),
    Pitches2026 = n(),
    .groups = "drop") %>%
  arrange(Batter)

# ---- similarity-functions ----
pitch_family_priors <- development %>%
  group_by(PitcherThrows, PitchFamily) %>%
  summarise(PriorRV = weighted.mean(PitchRV, RecencyWeight, na.rm = TRUE), .groups = "drop")

make_target_shapes <- function(
  pitcher_name, pitcher_team = NULL, target_data = current_arsenal_data) {
  pitcher_key <- normalize_player(pitcher_name)
  pitcher_pitches <- target_data %>% filter(PitcherKey == pitcher_key)
  if (!is.null(pitcher_team)) {
    pitcher_pitches <- pitcher_pitches %>% filter(PitcherTeam == pitcher_team)
  }
  if (nrow(pitcher_pitches) == 0) {
    stop("No qualifying 2026 pitches found for pitcher: ", pitcher_name)}
  total <- nrow(pitcher_pitches)
  pitcher_pitches %>%
    group_by(PitcherKey, Pitcher, PitcherTeam, PitcherThrows, PitchFamily) %>%
    summarise(
      TargetPitches = n(), Usage = n() / total,
      across(all_of(z_features), function(x) mean(x, na.rm = TRUE)), .groups = "drop")}

weighted_rate <- function(x, w) {
  valid <- !is.na(x) & !is.na(w)
  if (!any(valid)) return(NA_real_)
  weighted.mean(as.numeric(x[valid]), w[valid])}

mac_matchup <- function(
  pitcher_name, batter_name, pitcher_team = NULL,
  threshold = params$similarity_threshold,
  history = development, target_data = current_arsenal_data) {
  batter_key <- normalize_player(batter_name)
  hitter_history <- history %>% filter(BatterKey == batter_key)
  if (nrow(hitter_history) == 0) stop("No qualifying history found for batter: ", batter_name)

  batter_display <- hitter_directory %>%
    filter(BatterKey == batter_key) %>%
    pull(Batter)
  if (length(batter_display) == 0) batter_display <- batter_name

  shapes <- make_target_shapes(pitcher_name, pitcher_team, target_data)
  detail <- vector("list", nrow(shapes))
  for (i in seq_len(nrow(shapes))) {
    candidate <- hitter_history %>% filter(
      PitcherThrows == shapes$PitcherThrows[i], PitchFamily == shapes$PitchFamily[i])
    if (nrow(candidate) > 0) {
      x <- as.matrix(as.data.frame(candidate)[, z_features, drop = FALSE])
      target <- as.numeric(as.data.frame(shapes)[i, z_features, drop = FALSE])
      distance <- sqrt(rowSums((x - matrix(target, nrow(x), length(target), byrow = TRUE))^2))
      similar <- candidate[distance <= threshold, ]} else {
      distance <- numeric()
      similar <- candidate}

    prior <- pitch_family_priors %>% filter(
      PitcherThrows == shapes$PitcherThrows[i], PitchFamily == shapes$PitchFamily[i]) %>% pull(PriorRV)
    if (length(prior) == 0) prior <- mean(history$PitchRV, na.rm = TRUE)

    weighted_n <- sum(similar$RecencyWeight)
    observed_rv <- if (nrow(similar) > 0) {
      weighted.mean(similar$PitchRV, similar$RecencyWeight, na.rm = TRUE)} else prior
    shrinkage_weight <- weighted_n / (weighted_n + params$shrinkage_pitches)
    adjusted_rv <- shrinkage_weight * observed_rv + (1 - shrinkage_weight) * prior
    pa_ends <- sum(similar$IsPAEnd)

    detail[[i]] <- shapes[i, ] %>% mutate(
      Batter = batter_display[[1]],
      SimilarPitches = nrow(similar),
      WeightedSimilarPitches = weighted_n,
      MeanDistance = if (nrow(similar) > 0) mean(distance[distance <= threshold]) else NA_real_,
      RV100 = 100 * adjusted_rv,
      WhiffRate = weighted_rate(similar$IsWhiff[similar$IsSwing], similar$RecencyWeight[similar$IsSwing]),
      HardHitRate = weighted_rate(similar$IsHardHit[similar$IsBIP], similar$RecencyWeight[similar$IsBIP]),
      WOBA = if (pa_ends > 0) sum(similar$WOBAValue[similar$IsPAEnd]) / pa_ends else NA_real_,
      SampleQualified = SimilarPitches >= params$minimum_similar_pitches)}

  detail <- bind_rows(detail)
  overall <- detail %>% summarise(
    Pitcher = first(Pitcher), PitcherTeam = first(PitcherTeam), Batter = first(Batter),
    ProjectedRV100 = sum(Usage * RV100),
    SimilarityCoverage = sum(Usage * SampleQualified),
    SimilarPitches = sum(SimilarPitches), PitcherPitches = sum(TargetPitches))
  list(overall = overall, by_pitch_family = detail)}

# ---- bullpen-ranking-function ----
team_code_lookup <- clean_2026 %>%
  mutate(TeamName = case_when(
    TopBottom == "Top" ~ HomeTeam,
    TopBottom == "Bottom" ~ AwayTeam,
    TRUE ~ NA_character_)) %>%
  filter(!is.na(PitcherTeam), !is.na(TeamName)) %>%
  count(PitcherTeam, TeamName, sort = TRUE) %>%
  group_by(PitcherTeam) %>%
  slice_max(n, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  select(PitcherTeam, TeamName)

rank_bullpen <- function(
  batter_names, bullpen_team, threshold = params$similarity_threshold, top_n = 15) {
  eligible_pitchers <- current_arsenal_data %>%
    filter(PitcherTeam == bullpen_team) %>%
    group_by(PitcherKey) %>%
    summarise(
      Pitcher = str_squish(first(Pitcher)),
      PitcherPitches = n(),
      .groups = "drop") %>%
    filter(PitcherPitches >= params$minimum_pitcher_pitches)
  if (nrow(eligible_pitchers) == 0) stop("No qualifying pitchers found for: ", bullpen_team)

  results <- list()
  index <- 1L
  for (pitcher_index in seq_len(nrow(eligible_pitchers))) {
    for (batter_name in batter_names) {
      result <- tryCatch(
        mac_matchup(
          eligible_pitchers$PitcherKey[[pitcher_index]],
          batter_name,
          pitcher_team = bullpen_team,
          threshold = threshold
        )$overall,
        error = function(e) NULL)
      if (!is.null(result)) {
        results[[index]] <- result
        index <- index + 1L}}}

  long_results <- bind_rows(results)
  if (nrow(long_results) == 0) stop("No matchups could be calculated.")
  summary <- long_results %>%
    group_by(Pitcher, PitcherTeam, PitcherPitches) %>%
    summarise(
      LineupRV100 = mean(ProjectedRV100), MeanCoverage = mean(SimilarityCoverage),
      HittersRated = n_distinct(Batter), .groups = "drop") %>%
    filter(MeanCoverage >= params$minimum_matchup_coverage) %>%
    arrange(LineupRV100) %>%
    slice_head(n = top_n)

  qualified_pitchers <- summary$Pitcher
  matchup_matrix <- long_results %>%
    filter(Pitcher %in% qualified_pitchers) %>%
    select(Pitcher, Batter, ProjectedRV100) %>%
    pivot_wider(names_from = Batter, values_from = ProjectedRV100)
  list(summary = summary, matchups = matchup_matrix, long = long_results)}
