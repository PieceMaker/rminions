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
#' @param host The name or ip address of the redis server.
#' @param iter A list to be iterated over.
#' @param variables Per \code{plyr} docs, variables to split data frame by, as
#' as.quoted variables, a formula or character vector.
#' @param func The function to be executed
#' @param ... Parameters to be passed to \code{func}.
#' @param resultsQueue The queue to store returned results in.
#' @param errorQueue The queue to store any returned errors in.
#' @param buildJobsList The function that performs any required tasks and returns
#'   job list with keys Function, Parameters, and ResultsKey for workers. Defaults
#'   to generic \code{buildJobsList} function.
#' @param port The port the redis server is running on. Defaults to 6379.
#' @param jobsQueue A string giving the name of the queue where jobs will be placed.
#'   Defaults to \code{jobsqueue}.

llplyQueueJobs <- function(host, iter, func, ..., resultsQueue, errorQueue, buildJobsList = buildJobsList, port = 6379,
jobsQueue = "jobsqueue") {
    upload <- plyr::llply(
        .data = iter,
        .fun = buildJobsList,
        func = func,
        resultsQueue = resultsQueue,
        errorQueue = errorQueue,
        ...
    )

    conn <- rredis::redisConnect(host = host, port = port, returnRef = T)
    lapply(upload, rredis::redisRPush, key = jobsQueue)
    rredis::redisClose(conn)
}