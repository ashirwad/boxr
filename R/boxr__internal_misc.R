# From https://box-content.readme.io/reference#upload-a-file
# 
# Box only supports file names of 255 characters or less. Names that will not be
# supported are those that contain non-printable ascii, / or \, names with 
# trailing spaces, and the special names "." and "..".
box_filename <- function(x) {
  x <- iconv(x, from = "", to = "ascii")
  
  if (is.na(x))
    stop("box.com accepts only valid ASCII filenames. Filename conversion to",
         " ASCII via iconv() failed. See ?Encoding")
  
  if (nchar(x) > 255)
    stop("box.com accepts only filenames of 255 characters or less. Filename ",
         "is ", nchar(x), " characters long.")
  
  if (grepl("^[[:space:]]+|^\\.{1,2}$", x))
    stop('box.com file names may begin with a space, or be "." or "..".')
  x
}


# Validate ids supplied
box_id <- function(x) {
  if (!is.null(x) && any(is.na(bit64::as.integer64(x)))) 
    stop("box.com API ids must be (coercible to) 64-bit integers")
  if (!is.null(x))
    return(as.character(bit64::as.integer64(x)))
}

# helper to identify void values
is_void <- function(x) {
  is.null(x) ||
    identical(x, "") ||
    identical(nchar(x), integer(0)) ||
    all(is.na(x))
}

# helper to discriminate on void values, similar to %||%
`%|0|%` <- function(x, y) {
  if (is_void(x)) {
    return (y)
  }
  x
}


# Function to present different package startup messages, based on whether or
# not it looks like the user has used boxr before
boxrStartupMessage <- function() {
  
  new_user <- !file.exists("~/.boxr-oauth")
  
  if (new_user) {
    packageStartupMessage(
      "boxr: see `vignette(\"boxr\")` on how to authorize to your Box account."
    )
  }
}


# Short function to tidy up the variable which stores the creation of new remote
# directories, putting the id at the same place on each
dir_id_tidy <- function(x) {
  
  x <- as.character(x)
  
  before <- unlist(lapply(strsplit(x, "\\(id: "), function(x) x[1]))
  
  after  <- 
    paste("(id:", unlist(lapply(strsplit(x, "\\(id: "), function(x) x[2])))
  
  spaces <- lapply(
    nchar(before), 
    function(y) 
      paste(rep(" ", max(nchar(before)) - y), collapse = "")
  )
  
  paste0(before, spaces, after)
}


# A simple wrapper for box_auth, with defaul options suitable for running 
# at startup
boxAuthOnAttach <- function() {
  if (Sys.getenv("BOX_AUTH_ON_ATTACH") == "TRUE")
    try(
      box_auth(
        cache = Sys.getenv("BOX_TOKEN_CACHE"),
        interactive = FALSE, 
        write.Renv = FALSE
      ),
      silent = TRUE
    )
}


# A version of cat which only works if the package options are set to verbose,
# and pads out the message with spaces so that it fills/wipes the console.
# It also appends \r to the start of each message, so that you can stick them in
# a loop, for example
catif <- function(...) {
  if (getOption("boxr.verbose")) {
    txt <- paste(..., collapse = " ")
    width <- max(getOption("width"), nchar(txt))
    
    cat(paste0(
      "\r", txt, 
      paste(rep(" ", max(0, width - nchar(txt) - 1)), collapse = "")
    ))
  }
}


# A function to convert the datetime strings that the box api uses, to something
# R can understand
box_datetime <- function(x) {
  # R has trouble figuring out the time format
  x <- as.character(x)
  # Split out the date/time part
  dt <- substr(x, 1, nchar(x) - 6)
  # and the timezone offset
  tz <- substr(x, nchar(x) - 5, nchar(x))
  
  tz <- gsub(":", "", tz)
  
  # Note, the timzeone of the datetime boject will be the system default,
  # bit it's value will have been adjusted to account for the timzone of x
  as.POSIXct(paste0(dt, tz), format = "%Y-%m-%dT%H:%M:%S%z")
}

checkAuth <- function() {
  if (is.null(getOption("boxr.token") %||% getOption("boxr_token_jwt")))
    stop("It doesn't look like you've set up authentication for boxr yet.\n",
         "See ?box_auth or ?box_auth_jwt")
}


# Something for keeping dir strings a constant length for calls to cat
trimDir <- function(x, limit = 25) {
  n <- nchar(x)
  if (n > limit)
    return(paste0("...", substr(x, n - limit + 3, n)))
  
  if (n < limit)
    return(paste0(paste(rep(" ", limit - n), collapse = ""), x)) else x
}


# Very basic stuff --------------------------------------------------------

trunc_end <- function(x, max_char = 30, suffix = "...") {
  ifelse(
    nchar(x) > max_char,
    paste0(
      substr(x, 1, max_char - nchar(suffix)), suffix
    ),
    x
  )
}


trunc_start <- function(x, max_char = 30, prefix = "...") {
  ifelse(
    nchar(x) > max_char,
    paste0(
      prefix, substr(x, nchar(x) - max_char + nchar(prefix) + 1, nchar(x))
    ),
    x
  )
}


# For testing -------------------------------------------------------------

# A function to auth using the test credentials (not part of the git
# repository). Used for ad-hoc tests.
box_test_auth <- function() {
  box_auth(
    client_id     = readLines(".client_id"),
    client_secret = readLines(".client_secret"),
    interactive = FALSE,
    cache = ".boxr-oauth",
    write.Renv = FALSE
  )
}


# Yoinked from the dev build of testthat
# https://github.com/hadley/testthat/blob/0835a9e40d3a2fbaac47cbe8f86239e231623b51/R/utils.r
skip_on_travis <- function() {
  if (!identical(Sys.getenv("TRAVIS"), "true")) return()
  
  testthat::skip("On Travis")
}


# A function to create a directory structure for testing
create_test_dir <- function() {
  # Clear out anything that might already be there
  unlink("test_dir", recursive = TRUE, force = TRUE)
  
  # Set up a test directory structure
  lapply(
    c("test_dir/dir_11", "test_dir/dir_12/dir_121/dir_1211", "test_dir/dir_13"),
    function(x) dir.create(x, recursive = TRUE)
  )
  
  # Create a test file
  writeLines("This is a test file.", "test_dir/testfile.txt")
  
  # Copy the test file into a few of the directories, deliberately leaving some
  # blank
  lapply(
    paste0(list.dirs("test_dir", recursive = TRUE)[-5], "/testfile.txt"),
    function(x) file.copy("test_dir/testfile.txt", x)
  )
  
  return()  
}


# A function to modify that directory structure
modify_test_dir <- function() {
  # Delete a directory
  unlink("test_dir/dir_13", recursive = TRUE, force = TRUE)
  # Add a new directory
  dir.create("test_dir/dir_14")
  # Update a file
  writeLines("This is an updated file", "test_dir/testfile.txt")
  # Add a file
  writeLines("This is an new file", "test_dir/newtestfile.txt")
  # Delete a file  
  unlink("test_dir/dir_12/testfile.txt")
  
  return()
}


# A function to clear out a box.com directory
clear_box_dir <- function(dir_id) {
  dir.create("delete_me", showWarnings = FALSE)
  box_push(dir_id, "delete_me", delete = TRUE)
  unlink("delete_me", recursive = TRUE, force = TRUE)
}


modify_remote_dir <- function()
  suppressMessages({
      tf1 <- 
        normalizePath(paste0(tempdir(), "/testfile.txt"), mustWork = FALSE)
      
      tf2 <- 
        normalizePath(paste0(tempdir(), "/newtestfile.txt"), mustWork = FALSE)
      
      writeLines("This text is NEW!", tf1)
      writeLines("This text is NEW!", tf2)
      
      bls <- as.data.frame(box_ls(0))
      
      # Upload a new file
      # test_dir/newtestfile.txt
      box_ul(0, tf2)
      
      # Update an existing file: 
      # test_dir/dir_11/testfile.txt
      box_ul(bls$id[bls$name == "dir_12"], tf1)
      
      # Create a new dir, and put a new file in it
      # test_dir/another_dir/newtestfile.txt
      new_dir <- boxDirCreate("another_dir", 0)
      box_ul(httr::content(new_dir)$id, tf2)
      
      # Delete a file
      # test_dir/testfile.txt
      box_delete_file(bls$id[bls$name == "testfile.txt"])
      
      # Delete a a folder (it has a file in it)
      box_delete_folder(bls$id[bls$name == "dir_11"])
      
    })


#' @keywords internal
forRCMDCheck <- function(cran = "http://cran.r-project.org/") {
  if (FALSE) {
    httpuv::encodeURI(cran)
    mime::guess_type(cran)
    rio::import(cran)
  }
}


# API ---------------------------------------------------------------------

#' Common Box API client-errors 
#' 
#' @description 
#' This function returns a subset of known Box API error codes, based on the
#' [Box API docs](https://developer.box.com/guides/api-calls/permissions-and-errors/common-errors/).
#' This function is only intended to be used as an argument to `httr::RETRY()` to prevent
#' successive API requests when the orignal request succeeded but returned a error unrelated
#' to establishing a connection.
#' 
#' @return `numeric` vector containing HTTP status-codes.
#' @noRd
#' 
box_terminal_http_codes <- function() {
  # https://developer.box.com/guides/api-calls/permissions-and-errors/common-errors/ 
  c(
    400, # Bad request
    401, # Unauthorized
    403, # Forbidden
    404, # Not found
    405, # Method not allowed
    410, # Gone
    411, # Length required
    412, # Precondition failed
    413, # Request entity too large
    415  # Unsupported media type
  )
}

