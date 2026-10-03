library(jsonlite)
library(dplyr)

get_batting_season <- function(season) {
  # Build the URL using the season supplied to the function.
  url <- paste0(
    "https://statsapi.mlb.com/api/v1/stats",
    "?stats=season",
    "&group=hitting",
    "&season=", season,
    "&sportIds=1",
    "&playerPool=ALL",
    "&limit=10000",
    "&gameType=R")
  
  # Download that season's data.
  response <- fromJSON(url)
  raw_batting <- response$stats$splits[[1]]
  
  # Create the player-season table.
  batting <- tibble(
    player_id = raw_batting$player$id,
    player_name = raw_batting$player$fullName,
    season = as.integer(raw_batting$season),
    age = raw_batting$stat$age,
    pa = raw_batting$stat$plateAppearances,
    strikeouts = raw_batting$stat$strikeOuts,
    walks = raw_batting$stat$baseOnBalls,
    at_bats = raw_batting$stat$atBats,
    doubles = raw_batting$stat$doubles,
    triples = raw_batting$stat$triples,
    home_runs = raw_batting$stat$homeRuns) |>
    filter(pa > 0) |>
    mutate(
      k_rate = strikeouts / pa,
      bb_rate = walks / pa, 
      iso = (doubles + 2 * triples + 3 * home_runs) /
        na_if(at_bats, 0L))
  
  # Check that the table meets our expectations.
  duplicates <- batting |>
    count(player_id, season) |>
    filter(n > 1)
  
  stopifnot(
    nrow(batting) > 0,
    nrow(duplicates) == 0,
    !anyNA(select(batting, -iso)),
    all(is.na(batting$iso) == (batting$at_bats == 0)),
    all(batting$iso[batting$at_bats > 0] >= 0 &
          batting$iso[batting$at_bats > 0] <= 3),
    all(batting$k_rate >= 0 & batting$k_rate <= 1),
    all(batting$bb_rate >= 0 & batting$bb_rate <= 1))
  return(batting)}

seasons <- 2010:2026

batting <- bind_rows(
  lapply(seasons, get_batting_season))

batting |>
  group_by(season) |>
  summarise(
    players = n(),
    total_pa = sum(pa),
    .groups = "drop")

dir.create("data", showWarnings = FALSE)
saveRDS(batting, "data/batting_seasons.rds")