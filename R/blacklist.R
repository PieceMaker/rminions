#' Returns a list of disallowed functions.
#' 
#' \code{blacklist} returns a list of functions that are not allowed
#' to be executed. The package name containing the function is a
#' key the value of this key is a list of the names of all functions
#' in this package that are disallowed.
#' 
#' @return list

blacklist <- function() {
    return(list(
        base = c('system', 'system2')
    ))
}