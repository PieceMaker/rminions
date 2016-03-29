#' This function constructs all jobs and adds them to the specified queue.
#'
#' For each iterator, \code{dlplyQueueJobs} takes the function to be executed
#' and any parameters the function needs, bundles them into a job list, and
#' pushes them to the specified queue.
#'
#' \code{iter} is a data frame to iterate over. Use \code{variables} to
#' specify how to split it.
#'
#' @import plyr rredis
#'
#' @export
#'
#' @param host The name or ip address of the redis server.
#' @param iter Data frame to be iterated over.
#' @param variables Per \code{plyr} docs, variables to split data frame by, as
#' as.quoted variables, a formula or character vector.
#' @param func The function to be executed
#' @param buildJobsList The function that performs any required tasks and returns
#'   job list with keys Function, Params, and ResultsKey for workers. Defaults
#'   to generic \code{buildJobsList} function.
#' @param port The port the redis server is running on. Defaults to 6379.
#' @param jobsQueue A string giving the name of the queue where jobs will be placed.
#'   Defaults to \code{jobsqueue}.

dlplyQueueJobs <- function(host, iter, variables, func, ..., resultsKey, buildJobsList = buildJobsList, port = 6379, jobsQueue = "jobsqueue") {
    upload <- plyr::dlply(
        .data = iter,
        .variables = variables,
        .fun = buildJobsList,
        func = func,
        resultsKey = resultsKey,
        ...
    )

    conn <- rredis::redisConnect(host = host, port = port, returnRef = T)
    lapply(upload, rredis::redisRPush, key = jobsQueue)
    rredis::redisClose(conn)
}