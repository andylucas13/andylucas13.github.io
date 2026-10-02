params <- list(
  data_path_2025 = "/Users/andy/Documents/Coding Projects/P4 Trackman Data/2025 Trackman/power4_trackman_pitch_by_pitch_all.csv",
  data_path_2026 = "/Users/andy/Documents/Coding Projects/P4 Trackman Data/power4_trackman_pitch_by_pitch_all.csv",
  validation_start = "2026-04-15",
  similarity_threshold = 1.50,
  similarity_thresholds_to_test = c(1.00, 1.50, 2.00),
  validation_sample_n = 2500L,
  shrinkage_pitches = 50L,
  weight_2025 = 1L,
  weight_2026 = 2L,
  minimum_similar_pitches = 25L,
  minimum_pitcher_pitches = 50L,
  minimum_matchup_coverage = 0.50)

source("model_backend.R", local = TRUE)
