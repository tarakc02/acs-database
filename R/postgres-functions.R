connect_postgres <- function() {
    DBI::dbConnect(
        RPostgreSQL::PostgreSQL(), 
        user = Sys.getenv("POSTGRES_USERNAME"), 
        password = Sys.getenv("POSTGRES_PW"),
        dbname = "postgres",
        host = "localhost",
        port = 5432
    )
}

disconnect_postgres <- function(connection) {
    DBI::dbDisconnect(connection)
}

query_postgres <- function(connection, query) {
    dplyr::tbl_df(DBI::dbGetQuery(connection, query))
}

read_query <- function(filename) {
    text_con <- file(filename, open = "rt")
    on.exit(close(text_con))
    paste(readLines(text_con), collapse = "\n")
}
