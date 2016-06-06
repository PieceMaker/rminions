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
#' keys: \code{Function}, \code{Parameters}, \code{ResultsQueue}, \code{ErrorQueue}, and
#' optionally \code{Packages}.
#'
#' \code{Function} is the main function that controls the job and holds the core logic. Even
#' if the desired job is a simple script, the script should be wrapped in a function which
#' can then be passed to the worker. For more complex jobs that call subfunctions, it is
#' recommended that you create a package with these subfunctions and have \code{Function}
#' load this package. If \code{Function} must take input paremeters, define it as as a
#' function of one parameter (here referenced as \code{Parameters}), i.e.
#' \code{func(Parameters)}. Parameters will be a list and every desired parameter will be
#' a key.
#'
#' \code{Parameters} is a list of all the parameters to be passed to \code{Function}.
#'
#' \code{ResultsQueue} will be a string with the name of the redis queue to store any
#' returned results in.
#'
#' \code{ErrorQueue} will be a string with the name of the redis queue to store any errors
#' thrown while running the job.
#'
#' \code{Packages} is an optional key. This accepts a vector of string(s) containing the
#' name(s) of any package(s) that need to be loaded before running \code{Function}. This
#' will typically be used whenever the function to be run has been bundled into a package
#' and you need to load it beforehand. The package(s) will be unloaded after \code{Function}
#' has finished running to help prevent memory issues.
#'
#' @import plyr rredis R.utils Rbunyan
#'
#' @export
#'
#' @param host The name or ip address of the redis server.
#' @param port The port the redis server is running on. Defaults to 6379.
#' @param jobsQueue A string giving the name of the queue where jobs will be placed.
#'   Defaults to \code{jobsqueue}.
#' @param logLevel A string, required. 'TRACE', 'DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL'.
#'   Level threshold required to trigger log write. You can change the level on an
#'   existing log.
#' @param logFileDir A string giving the directory to store worker log files if logging is
#'   enabled. Defaults to \code{/var/log/R/}. Set to \code{stdout} to output logs to
#'   standard out.

minionWorker <- function(host, port = 6379, jobsQueue = "jobsqueue", logLevel = 'DEBUG', logFileDir = "/var/log/R") {
    workerHost <- as.character(R.utils::System$getHostname())
    workerID <- paste0(workerHost, '-worker-', Sys.getpid())
    if(logFileDir == 'stdout') {
        logFile = 'stdout'
    } else {
        logFile = paste0(workerID, '.log')
    }

    Rbunyan::bunyanSetLog(level = logLevel, memlines = 0, logpath = logFileDir, logfile = logFile)
    Rbunyan::bunyanLog.info(
        sprintf(
            "Started worker on host %s.",
            workerHost
        )
    )

    tryCatch(
        {
            conn <- rredis::redisConnect(host = host, port = port, returnRef = T)
        },
        error = function(e) {
            Rbunyan::bunyanLog.error(
                sprintf(
                    "An error occurred while connecting to Redis server: %s",
                    e
                )
            )
            stop(e)
        }
    )

    while(1) {
        tryCatch(
            {
                job <- rredis::redisBRPopLPush(jobsQueue, workerID)

                packages <- job$Packages
                if(!is.null(packages)) {
                    plyr::a_ply(packages, 1, library, character.only = T)
                }
                func <- job$Function
                params <- job$Parameters
                #Pass in redis connection in case it is needed inside func
                params$redisConn <- conn
                resultsQueue <- job$ResultsQueue
                errorQueue <- job$ErrorQueue

                if(is.null(errorQueue)) {
                    Rbunyan::bunyanLog.error("ErrorQueue not provided.")
                    job$Error <- "ErrorQueue not provided."
                    rredis::redisRPush(
                        "missingErrorQueueErrors",
                        job
                    )
                } else if(is.null(func)) {
                    Rbunyan::bunyanLog.error("Function not provided.")
                    job$Error <- "Function not provided."
                    rredis::redisRPush(
                        "errorQueue",
                        job
                    )
                } else if(is.null(params)) {
                    Rbunyan::bunyanLog.error("Parameters not provided.")
                    job$Error <- "Parameters not provided."
                    rredis::redisRPush(
                        "errorQueue",
                        job
                    )
                } else if(is.null(resultsQueue)) {
                    Rbunyan::bunyanLog.error("ResultsQueue not provided.")
                    job$Error <- "ResultsQueue not provided."
                    rredis::redisRPush(
                        "errorQueue",
                        job
                    )
                } else {
                    tryCatch(
                        {
                            results <- func(params)
                            Rbunyan::bunyanLog.debug(
                                sprintf(
                                    "Sending results to queue %s: %s",
                                    resultsQueue,
                                    jsonlite::serializeJSON(results)
                                )
                            )
                            rredis::redisRPush(resultsQueue, results)
                        },
                        error = function(e) {
                            Rbunyan::bunyanLog.error(
                                sprintf(
                                    "An error occurred while executing R function: %s",
                                    e
                                )
                            )
                            job$Error <- e
                            rredis::redisRPush(errorQueue, job)
                        },
                        finally = {
                            rredis::redisDelete(workerID)
                            if(!is.null(packages)) {
                                plyr::a_ply(
                                    packages,
                                    1,
                                    function(package) {
                                        package <- paste0("package:", package)
                                        detach(package, unload = T, character.only = T)
                                    }
                                )
                            }
                        }
                    )
                }
            },
            error = function(e) {
                Rbunyan::bunyanLog.error(
                    sprintf(
                        "An unhandled error occurred while executing R function: %s",
                        e
                    )
                )
                if(is.list(job)) {
                    job$Error <- e
                    if(is.null(job$errorQueue)) {
                        rredis::redisRPush('unhandledErrors', job)
                    } else {
                        rredis::redisRPush(job$errorQueue, job)
                    }
                } else {
                    rredis::redisRPush('unhandledErrors', e)
                }
            }
        )
    }
}