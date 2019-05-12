#' A function that watches a message queue and starts working a job when one is available.
#'
#' \code{minionWorker} is a blocking function that will completely block the R instance
#' running it. It immediately performs some housekeeping by gathering logging information
#' and connecting to the message queue. Once connected, it performs a blocking pop on the
#' \code{jobsQueue} and waits until it receives a bundled job message. Once a message is
#' received, it pulls the specified function for the specified package and runs it with
#' the bundled parameters and stores any returned results in the bundled response key.
#'
#' \code{minionWorker} is the core of the \code{rminions} package and multiple R
#' processes running this function should be spawned. The goal is to spawn just enough
#' workers that the full cpu resources of the system running them are maxed out when under
#' full jobs load. A good rule of thumb is that you should have \code{number of cores + 2}
#' workers running on a system.
#'
#' The minion worker is constructed to work with nearly all tasks. In order to accomplish
#' this, job messages need to be of a specific format. Job message must be lists with the
#' following keys: \code{package}, \code{func}, \code{parameters}, \code{resultsQueue},
#' and optionally, \code{errorQueue}.
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
#' \code{resultsQueue} is required and will be a string with the name of the redis queue to
#' store any returned results in. If not provided, an error will be returned in the queue
#' "missingResultsQueueErrors".
#'
#' \code{errorQueue} will be a string with the name of the redis queue to store any errors
#' thrown while running the job. If not specified, it will default to \code{resultsQueue}.
#'
#' @import plyr rredis R.utils Rbunyan jsonlite
#'
#' @export
#'
#' @param host The name or ip address of the redis server.
#' @param port The port the redis server is running on. Defaults to 6379.
#' @param jobsQueue A string giving the name of the queue where jobs will be placed.
#'   Defaults to \code{jobsQueue}.
#' @param logLevel A string, required. 'TRACE', 'DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL'.
#'   Level threshold required to trigger log write. You can change the level on an
#'   existing log.
#' @param logFileDir A string giving the directory to store worker log files if logging is
#'   enabled. Defaults to \code{stdout} which outputs logs to standard out. Specify directory
#'   if you want logs to be written to a file. If a directory is specified, then logs will be
#'   saved in that directory to a file with name \code{<host>-worker-<pid>.log}.
#' @param useJSON Flag specifying whether jobs and results will be sent in JSON format. Defaults to false
#    so R-specific objects are preserved in transit. If sending jobs from languages other than R, set useJSON
#    to true and make sure jobs are defined in the JSON format and the function being executed does not require
#    any R-specific objects.

minionWorker <- function(host, port = 6379, jobsQueue = "jobsQueue", logLevel = 'DEBUG', logFileDir = "stdout", useJSON = F) {
    workerHost <- as.character(R.utils::System$getHostname())
    workerID <- paste0(workerHost, '-worker-', Sys.getpid())
    if(logFileDir == 'stdout') {
        logFileDir = ''
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

    Rbunyan::bunyanLog.info(
        sprintf(
            "Connecting to Redis at host %s on port %s.",
            host,
            port
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
                if(useJSON) {
                    job <- jsonlite::fromJSON(job)
                }
                package <- job$package
                func <- job$func
                params <- job$parameters
                resultsQueue <- job$resultsQueue
                errorQueue <- job$errorQueue
                if(is.null(errorQueue)) {
                    errorQueue <- resultsQueue
                }
                if(is.null(resultsQueue)) {
                    Rbunyan::bunyanLog.error('"resultsQueue" not provided.')
                    job$error <- '"resultsQueue" not provided.'
                    job$status <- "failed"
                    if(useJSON) {
                        job <- jsonlite::toJSON(job)
                    }
                    rredis::redisRPush(
                        "missingResultsQueueErrors",
                        job
                    )
                } else if(is.null(package)) {
                    Rbunyan::bunyanLog.error('"package" not provided.')
                    job$error <- '"package" not provided.'
                    job$status <- "failed"
                    if(useJSON) {
                        job <- jsonlite::toJSON(job)
                    }
                    rredis::redisRPush(
                        "errorQueue",
                        job
                    )
                } else if(is.null(func)) {
                    Rbunyan::bunyanLog.error('"func" not provided.')
                    job$error <- '"func" not provided.'
                    job$status <- "failed"
                    if(useJSON) {
                        job <- jsonlite::toJSON(job)
                    }
                    rredis::redisRPush(
                        "errorQueue",
                        job
                    )
                } else if(is.null(params)) {
                    Rbunyan::bunyanLog.error('"params" not provided.')
                    job$error <- '"params" not provided.'
                    job$status <- "failed"
                    if(useJSON) {
                        job <- jsonlite::toJSON(job)
                    }
                    rredis::redisRPush(
                        "errorQueue",
                        job
                    )
                } else {
                    tryCatch(
                        {
                            func <- getFromNamespace(func, ns = package)
                            # TODO: Try to make the below call safer
                            results <- do.call(func, params)
                            job$results <- results
                            job$status <- "succeeded"
                            if(useJSON) {
                                job <- jsonlite::toJSON(job)
                                Rbunyan::bunyanLog.debug(
                                    sprintf(
                                        "Sending results to queue %s: %s",
                                        resultsQueue,
                                        job
                                    )
                                )
                            } else {
                                Rbunyan::bunyanLog.debug(
                                    sprintf(
                                        "Sending results to queue %s: %s",
                                        resultsQueue,
                                        jsonlite::serializeJSON(job)
                                    )
                                )
                            }
                            rredis::redisRPush(resultsQueue, job)
                        },
                        error = function(e) {
                            Rbunyan::bunyanLog.error(
                                sprintf(
                                    'An error occurred while executing "%s::%s": %s',
                                    package,
                                    func,
                                    e
                                )
                            )
                            job$error <- e
                            job$status <- "failed"
                            if(useJSON) {
                                job <- jsonlite::toJSON(job)
                            }
                            rredis::redisRPush(errorQueue, job)
                        },
                        finally = {
                            rredis::redisDelete(workerID)
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
                    job$error <- e
                    job$status <- "catastrophic"
                    if(useJSON) {
                        job <- jsonlite::toJSON(job)
                    }
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