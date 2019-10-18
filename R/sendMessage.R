#' A function that takes the required information for a job and sends it to the queue.
#'
#' \code{sendMessage} takes the required inputs for a request job, bundles them into the
#' correct format, and ships them off to the queue.
#'
#' \code{package} is the name of the package containing the function that will be executed.
#'
#' \code{func} is the name of the function, contained in the specified package, that you
#' wish to execute with this request. If \code{useJSON} is false, \code{func} can take any
#' type of parameter. If \code{useJSON} is true, then \code{func} should only take R data
#' as parameters that can be converted to and from JSON, i.e. strings, numbers, simple vectors,
#' etc.
#'
#' \code{parameters} is a named list of all the parameters to be passed to \code{func}. The
#' names must match those of the parameters \code{func} expects.
#'
#' \code{resultsQueue} will be a string with the name of the redis queue to store any
#' returned results in. Returned results will have a \code{status} property set to "succeeded"
#' and a \code{results} property containing the results of the function execution. Defaults
#' to "resultsQueue".
#'
#' \code{errorQueue} will be a string with the name of the redis queue to store any errors
#' thrown while running the job. Note that returned errors will have \code{status} "failed" or
#' "catastrophic", so \code{errorQueue} can match \code{resultsQueue} and you can separate
#' message types by checking their status.
#'
#' @import redux jsonlite
#'
#' @export
#'
#' @param conn An open redux hiredis connection.
#' @param jobsQueue A string giving the name of the queue where jobs will be placed.
#'   Defaults to \code{jobsqueue}.
#' @param package A string giving the name of the package containing the function to execute.
#' @param func The name of the function in \code{package} to execute.
#' @param ... All parameters to be passed to \code{func}.
#' @param resultsQueue A string giving the name of the queue to send results to. Defaults to "resultsQueue".
#' @param errorQueue A string giving the name of the queue to send errors to. Defaults to "errorQueue".
#' @param useJSON Flag specifying whether jobs and results will be sent in JSON format. Defaults to false
#    so R-specific objects are preserved in transit. If sending jobs from languages other than R, set useJSON
#    to true and make sure jobs are defined in the JSON format and the function being executed does not require
#    any R-specific objects. Need to make sure this flag matches the one \code{minionWorker} was started with.

sendMessage <- function(conn, jobsQueue = "jobsQueue", package, func, ..., resultsQueue = "resultsQueue",
    errorQueue = "errorQueue", useJSON = F) {
    job <- list(
        package = package,
        func = func,
        parameters = list(...),
        resultsQueue = resultsQueue,
        errorQueue = errorQueue
    )
    if(useJSON) {
        job <- jsonlite::toJSON(job, auto_unbox = T, digits = NA)
    } else {
        job <- redux::object_to_bin(job)
    }
    conn$LPUSH(jobsQueue, job)
}