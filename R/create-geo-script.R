create_geo_script <- function(geography, year, 
                          template = tiger_template,
                          header = tiger_header,
                          df = state_table) {
    
    df$year <- year
    df$geography <- tolower(geography)
    df$GEOGRAPHY <- toupper(geography)
    
    script <- vapply(
        rowSplit(df), 
        function(x) whisker.render(template, data = x),
        FUN.VALUE = character(1)
    )
    
    script <- paste(script, collapse = "\n")
    
    script <- paste(
        template_header,
        script,
        sep = "\n"
    )
    script
}
