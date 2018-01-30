if (!dir.exists("downloaded-data")) dir.create("downloaded-data")
if (!dir.exists("scripts")) dir.create("scripts")

library(rvest)
library(whisker)
library(magrittr)

# get a list of all states with fips/usps codes to fill in download/stage/load scripts
# each geography (tract, bg, etc) will have 1 file for each state
state_table <- read_html("https://www.census.gov/geo/reference/ansi_statetables.html")
state_table %<>% 
    html_node("table") %>%
    html_table
names(state_table) <- c("name", "fips", "usps")
state_table$fips <- sprintf("%02d", state_table$fips)

source("script-templates/tiger-templates.R")
source("R/create-geo-script.R")

# make tract script
dlgeo <- function(geo, year, fips) {
    GEO <- toupper(geo)
    geo <- tolower(geo)
    filepath <- paste0(
        "https://www2.census.gov/geo/tiger/TIGER", year, "/", 
        GEO, "/tl_",
        year, "_", fips, "_", geo, ".zip")
    destfile <- paste0(
        "C:/gisdata/ftp2.census.gov/geo/tiger/TIGER", year, "/", GEO,
        "/tl_", year, "_", fips, "_", geo, ".zip")
    download.file(filepath, destfile = destfile, quiet = TRUE)
}
library(dplyr); library(purrr)

safedl <- safely(dlgeo)

tract_dl_results <- state_table %>% 
    mutate(res = pmap(list(name, fips), function(n, f) 
        safedl("tract", year = year, fips = f)))

tbl_df(tract_dl_results) %>% mutate(res = map(res, "error")) %>% 
    filter(!map_lgl(res, is.null))

bg_dl_results <- state_table %>% 
    mutate(res = pmap(list(name, fips), function(n, f) 
        safedl("bg", year = year, fips = f)))

tbl_df(bg_dl_results) %>% mutate(res = map(res, "error")) %>% 
    filter(!map_lgl(res, is.null))


tract_script <- create_geo_script("tract", 2016)
cat(tract_script, file = "scripts/tracts.bat", append = FALSE)
shell("scripts\\tracts.bat > scripts\\tract-log.txt")

# make bg script
bg_script <- create_geo_script("bg", 2016)
cat(bg_script, file = "scripts/bg.bat", append = FALSE)
shell("scripts\\bg.bat > scripts\\bg-log.txt")

# download 5-year survey data:
download.file(
    "https://www2.census.gov/programs-surveys/acs/summary_file/2016/data/5_year_entire_sf/Tracts_Block_Groups_Only.tar.gz",
    destfile = "downloaded-data/acs-summary-files.tar.gz"
)

# and the geography files:
download.file(
    "https://www2.census.gov/programs-surveys/acs/summary_file/2016/data/5_year_entire_sf/2016_ACS_Geography_Files.zip",
    destfile = "downloaded-data/geography-files.zip"
)
unzip("downloaded-data/geography-files.zip",
      exdir = "downloaded-data/group2")
#####
#####
# now we have geometry, time to pull in survey data
# using scripts from teh census-reporter project (https://github.com/censusreporter/census-postgres)
source("R/postgres-functions.R")
con <- connect_postgres()
. <- function(filename) query_postgres(con, read_query(filename))
#query_postgres(con, read_query("sql/01-create-tmp-geoheader.sql"))
.("sql/01-create-tmp-geoheader.sql")
.("sql/02-drop-import-tables.sql")
.("sql/03-create-import-tables.sql")
.("sql/04-import-geoheader.sql")
.("sql/05-import-sequences.sql")
.("sql/06-create-geoheader.sql")
.("sql/07-parse-tmp-geoheader.sql")
.("sql/08-store-by-tables.sql")
.("sql/09-insert-into-tables.sql")
.("sql/10-view-stored-by-tables.sql")
.("sql/11-geoheader-comments.sql")
disconnect_postgres(con)

# import_seq <- readLines("sql/05-import-sequences.sql")
# keep <- stringr::str_detect(import_seq, "group2")
# import_seq <- import_seq[keep]
# writeLines(import_seq, "sql/05-import-sequences.sql")