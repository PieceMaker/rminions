#' This function constructs all jobs and adds them to the specified queue.
#'
#' For each iterator, \code{alplyQueueJobs} takes the function to be executed
#' and any parameters the function needs, bundles them into a job list, and
#' pushes them to the specified queue.
#'
#' \code{iter} can be a matrix, array, or data frame to iterate over. It can
#' also be an integer specifying how many times to repeat the job. Use the
#' \code{margins} argument to specify how to split \code{iter}. If \code{iter}
#' is an integer, then set \code{margins} to 1.
#'
#' @import plyr rredis
#'
#' @export
#'
#' @param iter Matrix, array, or data frame to be iterated over.
#' @param margins Per \code{plyr} docs, a vector giving the subscripts to
#'   split up data by. 1 splits up by rows, 2 by columns and c(1,2) by rows and
#'   columns, and so on for higher dimensions.
#' @param func The function to be executed
#' @param buildJobsList The function that performs any required tasks and returns
#'   job list with keys Function, Params, and ResultsKey for workers. Defaults
#'   to generic \code{buildJobsList} function.
#' @param jobsQueue A string giving the name of the queue where jobs will be placed.
#'   Defaults to \code{jobsqueue}.

alplyQueueJobs <- function(iter, margins, func, ..., resultsKey, buildJobsList = buildJobsList, jobsQueue = "jobsqueue") {
    upload <- plyr::alply(
        .data = iter,
        .margins = margins,
        .fun = buildJobsList,
        func = func,
        resultsKey = resultsKey,
        ...
    )

    lapply(upload, rredis::redisRPush, key = jobsQueue)
}