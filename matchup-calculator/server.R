function(input, output, session) {
  output$hitter_selector <- renderUI({
    req(input$opponent_team)

    hitters <- hitter_directory
    if (input$opponent_team != "ALL") {
      hitters <- hitters %>% filter(CurrentTeam == input$opponent_team)
    }

    choices <- setNames(
      hitters$BatterKey,
      paste0(hitters$Batter, " (", hitters$CurrentTeam, ")"))
    preferred_hitter <- normalize_player("Lackey, Vahn")
    selected <- if (preferred_hitter %in% hitters$BatterKey) {
      preferred_hitter
    } else if (nrow(hitters) > 0) {
      hitters$BatterKey[[1]]
    } else {
      character()
    }

    selectizeInput(
      "lineup_hitters",
      "Opposing hitter or lineup",
      choices = choices,
      selected = selected,
      multiple = TRUE,
      options = list(
        placeholder = "Search and select up to nine hitters",
        maxItems = 9),
      width = "100%")
  })

  output$pitcher_selector <- renderUI({
    req(input$bullpen_team)
    pitchers <- current_arsenal_data %>%
      filter(PitcherTeam == input$bullpen_team) %>%
      group_by(PitcherKey) %>%
      summarise(Pitcher = str_squish(first(Pitcher)), Pitches = n(), .groups = "drop") %>%
      filter(Pitches >= params$minimum_pitcher_pitches) %>%
      arrange(Pitcher)

    pitcher_choices <- setNames(pitchers$PitcherKey, pitchers$Pitcher)

    selectizeInput(
      "detail_pitcher",
      "Pitcher for detailed report",
      choices = pitcher_choices,
      selected = if (nrow(pitchers) > 0) pitchers$PitcherKey[[1]] else character(),
      width = "100%")
  })

  calculator_result <- eventReactive(input$run_analysis, {
    req(input$bullpen_team, input$lineup_hitters, input$detail_pitcher)

    withProgress(message = "Calculating similar-pitch matchups", value = 0, {
      incProgress(0.15, detail = "Ranking the bullpen")
      ranking <- rank_bullpen(
        batter_names = input$lineup_hitters,
        bullpen_team = input$bullpen_team,
        threshold = input$distance_threshold,
        top_n = 25)

      incProgress(0.75, detail = "Building pitcher detail")
      detail <- mac_matchup(
        pitcher_name = input$detail_pitcher,
        batter_name = input$lineup_hitters[[1]],
        pitcher_team = input$bullpen_team,
        threshold = input$distance_threshold)

      incProgress(1, detail = "Complete")
      list(ranking = ranking, detail = detail)
    })
  }, ignoreInit = TRUE)

  output$matchup_headline <- renderUI({
    result <- calculator_result()
    summary <- result$ranking$summary

    if (nrow(summary) == 0) {
      return(div(
        class = "alert alert-warning",
        "No pitcher met the minimum similarity-coverage requirement. Increase the threshold or choose hitters with more history."))
    }

    best <- summary[1, ]
    div(
      class = "alert alert-primary",
      tags$strong(paste0("Best supported bullpen matchup: ", best$Pitcher)),
      tags$br(),
      paste0(
        "Estimated lineup RV/100: ", round(best$LineupRV100, 2),
        " | Mean similarity coverage: ", scales::percent(best$MeanCoverage, accuracy = 1),
        " | Hitters rated: ", best$HittersRated))
  })

  output$bullpen_table <- renderDT({
    summary <- calculator_result()$ranking$summary
    validate(need(nrow(summary) > 0, "No qualifying bullpen ranking at these settings."))

    datatable(
      summary,
      rownames = FALSE,
      extensions = "Buttons",
      options = list(
        pageLength = 15,
        dom = "tip",
        order = list(list(3, "asc")),
        scrollX = TRUE)) %>%
      formatRound("LineupRV100", 2) %>%
      formatPercentage("MeanCoverage", 0)
  })

  output$bullpen_plot <- renderPlot({
    summary <- calculator_result()$ranking$summary
    validate(need(nrow(summary) > 0, "No qualifying bullpen ranking at these settings."))

    ggplot(summary, aes(x = reorder(Pitcher, LineupRV100), y = LineupRV100, fill = MeanCoverage)) +
      geom_col(width = 0.72) +
      geom_hline(yintercept = 0, color = "gray35", linewidth = 0.4) +
      coord_flip() +
      scale_fill_gradient(low = "#9ecae1", high = "#08519c", labels = scales::percent) +
      labs(
        title = "Bullpen matchup ranking",
        subtitle = "Lower estimated RV/100 favors the pitcher",
        x = NULL,
        y = "Estimated lineup RV/100",
        fill = "Coverage") +
      theme_minimal(base_size = 12) +
      theme(panel.grid.major.y = element_blank())
  })

  output$pitch_family_table <- renderDT({
    detail <- calculator_result()$detail$by_pitch_family %>%
      select(
        PitchFamily, Usage, TargetPitches, SimilarPitches, MeanDistance,
        RV100, WhiffRate, HardHitRate, WOBA, SampleQualified)

    datatable(
      detail,
      rownames = FALSE,
      options = list(pageLength = 10, dom = "tip", scrollX = TRUE)) %>%
      formatPercentage(c("Usage", "WhiffRate", "HardHitRate"), 1) %>%
      formatRound(c("MeanDistance", "RV100", "WOBA"), 3)
  })

  output$pitch_family_plot <- renderPlot({
    detail <- calculator_result()$detail$by_pitch_family

    ggplot(detail, aes(x = reorder(PitchFamily, RV100), y = RV100, fill = Usage)) +
      geom_col(width = 0.7) +
      geom_hline(yintercept = 0, color = "gray35", linewidth = 0.4) +
      coord_flip() +
      scale_fill_gradient(low = "#bdd7e7", high = "#08519c", labels = scales::percent) +
      labs(
        title = paste0(first(detail$Pitcher), " vs. ", first(detail$Batter)),
        subtitle = "Pitch-family performance against similar historical pitches",
        x = NULL,
        y = "Estimated RV/100",
        fill = "Usage") +
      theme_minimal(base_size = 12) +
      theme(panel.grid.major.y = element_blank())
  })

  output$matchup_matrix <- renderDT({
    matrix <- calculator_result()$ranking$matchups
    numeric_columns <- setdiff(names(matrix), "Pitcher")

    datatable(
      matrix,
      rownames = FALSE,
      options = list(pageLength = 15, dom = "tip", scrollX = TRUE)) %>%
      formatRound(numeric_columns, 2)
  })

  output$download_bullpen <- downloadHandler(
    filename = function() paste0("bullpen-ranking-", input$bullpen_team, ".csv"),
    content = function(file) fwrite(calculator_result()$ranking$summary, file))

  output$download_detail <- downloadHandler(
    filename = function() paste0("pitcher-detail-", normalize_player(input$detail_pitcher), ".csv"),
    content = function(file) fwrite(calculator_result()$detail$by_pitch_family, file))

  output$download_matrix <- downloadHandler(
    filename = function() paste0("matchup-matrix-", input$bullpen_team, ".csv"),
    content = function(file) fwrite(calculator_result()$ranking$matchups, file))
}
