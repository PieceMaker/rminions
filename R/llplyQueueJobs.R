#' This function constructs all jobs and adds them to the specified queue.
#'
#' For each iterator, \code{llplyQueueJobs} takes the function to be executed
#' and any parameters the function needs, bundles them into a job list, and
#' pushes them to the specified queue.
#'
#' \code{iter} is a list to iterate over.
#'
#' @import plyr rredis
#'
#' @export
#'
#' @param iter A list to be iterated over.
#' @param variables Per \code{plyr} docs, variables to split data frame by, as
#' as.quoted variables, a formula or character vector.
#' @param func The function to be executed
#' @param buildJobsList The function that performs any required tasks and returns
#'   job list with keys Function, Params, and ResultsKey for workers. Defaults
#'   to generic \code{buildJobsList} function.
#' @param jobsQueue A string giving the name of the queue where jobs will be placed.
#'   Defaults to \code{jobsqueue}.

llplyQueueJobs <- function(iter, func, ..., resultsKey, buildJobsList = buildJobsList, jobsQueue = "jobsqueue") {
    upload <- plyr::llply(
        .data = iter,
        .fun = buildJobsList,
        func = func,
        resultsKey = resultsKey,
        ...
    )

    lapply(upload, rredis::redisRPush, key = jobsQueue)
}