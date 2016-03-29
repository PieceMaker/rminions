#' This is a generic function for bundling a job in the format required by the workers.
#'
#' \code{buildJobsList} takes a function, a result key, and any parameters the
#' function requires and returns a list in the form the workers can understand, i.e.
#' a list with the following keys: Function, Params, and ResultsKey.
#'
#' If the job you wish to run requires significant setup to define a job, it may be useful
#' to write a custom function to handle the construction of a job. This job can be passed
#' in place of \code{buildJobsList} in the \code{queueJobs} function.
#'
#' @export
#'
#' @param func The function to be executed.
#' @param ... Parameters to be passed to \code{func}.
#' @param resultsQueue The queue to store returned results in.
#' @param errorQueue The queue to store any returned errors in.

buildJobsList <- function(func, ..., resultsQueue, errorQueue) {
    return(
        list(
            Function = func,
            Params = list(...),
            ResultsQueue = resultsQueue,
            ErrorQueue = errorQueue
        )
    )
}