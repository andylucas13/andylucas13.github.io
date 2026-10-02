team_choices <- setNames(
  team_code_lookup$PitcherTeam,
  paste0(team_code_lookup$TeamName, " (", team_code_lookup$PitcherTeam, ")"))
default_team <- if ("PIT_PAN" %in% team_code_lookup$PitcherTeam) {
  "PIT_PAN"
} else {
  team_code_lookup$PitcherTeam[[1]]
}

hitter_team_codes <- sort(unique(hitter_directory$CurrentTeam))
hitter_team_labels <- team_code_lookup %>%
  filter(PitcherTeam %in% hitter_team_codes) %>%
  mutate(Label = paste0(TeamName, " (", PitcherTeam, ")"))
hitter_team_choices <- setNames(hitter_team_codes, hitter_team_codes)
matched_team_labels <- match(names(hitter_team_choices), hitter_team_labels$PitcherTeam)
names(hitter_team_choices)[!is.na(matched_team_labels)] <-
  hitter_team_labels$Label[matched_team_labels[!is.na(matched_team_labels)]]
hitter_team_choices <- c("All 2026 teams" = "ALL", hitter_team_choices)
default_opponent_team <- if ("GIT_YEL" %in% hitter_team_codes) {
  "GIT_YEL"
} else {
  hitter_team_codes[[1]]
}

ui <- fluidPage(
  tags$head(
    tags$style(HTML("
      body { background: #f5f7fa; }
      .app-title { margin-bottom: 4px; font-weight: 700; }
      .app-subtitle { color: #59636e; margin-bottom: 22px; }
      .well { background: #ffffff; border-radius: 10px; border-color: #d9e0e7; }
      .btn-primary { background: #164e82; border-color: #164e82; }
      .tab-content { background: #ffffff; padding: 18px; border: 1px solid #ddd;
                     border-top: 0; border-radius: 0 0 8px 8px; }
    "))),

  h2(class = "app-title", "Power 4 Bullpen Matchup Calculator"),
  p(
    class = "app-subtitle",
    "Select the bullpen, opposing team, and up to nine hitters. Lower estimated RV/100 favors the pitcher."),

  sidebarLayout(
    sidebarPanel(
      width = 3,
      selectizeInput(
        "bullpen_team",
        "Bullpen",
        choices = team_choices,
        selected = default_team,
        options = list(placeholder = "Search for a bullpen")),
      selectizeInput(
        "opponent_team",
        "Opposing team",
        choices = hitter_team_choices,
        selected = default_opponent_team,
        options = list(placeholder = "Search for an opposing team")),
      uiOutput("hitter_selector"),
      uiOutput("pitcher_selector"),
      sliderInput(
        "distance_threshold",
        "Similarity threshold",
        min = 1.00,
        max = 2.00,
        value = params$similarity_threshold,
        step = 0.05),
      actionButton(
        "run_analysis",
        "Run matchup analysis",
        class = "btn-primary",
        width = "100%"),
      br(), br(),
      helpText(
        "Pitchers require at least 50 tracked pitches and rankings require 50% similarity coverage.")),

    mainPanel(
      width = 9,
      uiOutput("matchup_headline"),
      tabsetPanel(
        tabPanel(
          "Bullpen ranking",
          br(),
          plotOutput("bullpen_plot", height = "420px"),
          DTOutput("bullpen_table"),
          br(),
          downloadButton("download_bullpen", "Download bullpen ranking")),
        tabPanel(
          "Pitcher detail",
          br(),
          plotOutput("pitch_family_plot", height = "360px"),
          DTOutput("pitch_family_table"),
          br(),
          downloadButton("download_detail", "Download pitch-family detail")),
        tabPanel(
          "Matchup matrix",
          br(),
          DTOutput("matchup_matrix"),
          br(),
          downloadButton("download_matrix", "Download matchup matrix"))))))
