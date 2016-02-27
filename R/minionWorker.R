#' A function that watches a message queue and starts working a job when one is available.
#'
#' \code{minionWorker} is a blocking function that will completely block the R instance
#' running it. It immediately performs some housekeeping by gathering logging information
#' and connecting to the message queue. Once connected, it performs a blocking pop on the
#' \code{jobsqueue} and waits until it receives a bundled job message. Once a message is
#' received, it runs the bundled function with the bundled parameters and stores any
#' returned results in the bundled response key.
#'
#' \code{minionWorker} is the core of the \code{redis-minions} package and multiple R
#' processes running this function should be spawned. The goal is to spawn just enough
#' workers that the full cpu resources of the system running them are maxed out when under
#' full jobs load. A good rule of thumb is that you should have \code{number of cores + 2}
#' workers running on a system.
#'
#' The minion worker is constructed to work with nearly all tasks. In order to accomplish
#' this, job messages need to be of a specific format. Job message must be lists with three
#' keys: \code{func}, \code{params}, and \code{resultsKey}.
#'
#' \code{func} is the main function that controls the job and holds the core logic. Even
#' if the desired job is a simple script, the script should be wrapped in a function which
#' can then be passed to the worker. For more complex jobs that call subfunctions, it is
#' recommended that you create a package with these subfunctions and have \code{func} load
#' this package. If \code{func} must take input paremeters, define it as as a function of
#' one parameter (here referenced as \code{params}), i.e. \code{func(params)}. Params will
#' be a list and every desired parameter will be a key
#'
#' \code{params} is a list of all the parameters to be passed to \code{func}.