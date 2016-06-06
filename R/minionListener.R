#' A function that subscribes to a channel and performs various server-wide R tasks.
#'
#' \code{minionListener} is a blocking function that will completely block the R
#' instance running it. It immediately performs some housekeeping by gathering
#' logging information and subscribing to the redis channel. Once subscribed, it
#' defines a callback function for the subscribed channel then monitors the channel
#' for messages to pass into the callback function and execute. This function is
#' primarily for installing packages on all minion servers simultaneously, but can
#' also be adapted to other server maintenance tasks.
#'
#' Since \code{minionListener} uses the Redis PUB/SUB system instead of the POP/PUSH
#' system that \code{minionWorker} uses. \code{minionListener} will receive all
#' messages published on the channel(s) it is subscribed to and will execute the
#' callback on them. Due to the blocking nature of R, it is possible that published
#' messages could be missed if the listener is in the middle of executing the
#' callback on a previous message. Thus it is recommended that you allow sufficient
#' processing time between publishing messages.
#'
#' Since each listener receives all messages on the subscribed channel, only one
#' listener needs to be run on each server.
#'
#' Note that this function makes use of the global environment when defining
#' callbacks. After testing, it appears this is the only way to successfully monitor
#' the PUB/SUB channels. Since the only purpose of this function is to monitor, this
#' should not cause any issues.
#'
#' @import rredis R.utils
#'
#' @export
#'
#' @param host The name or ip address of the redis server.
#' @param channels A list of functions defining channels to subscribe to with
#'   corresponding callbacks.
#' @param port The port the redis server is running on. Defaults to 6379.
#' @param logLevel A string, required. 'TRACE', 'DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL'.
#'   Level threshold required to trigger log write. You can change the level on an
#'   existing log.
#' @param logFileDir A string giving the directory to store worker log files if logging is
#'   enabled. Defaults to \code{/var/log/R}. Set to \code{stdout} to output logs to
#'   standard out.

minionListener <- function(host, channels, port = 6379, logLevel = 'DEBUG', logFileDir = "/var/log/R") {
    globalEnvironment <- globalenv()

    listenerHost <- as.character(R.utils::System$getHostname())
    listenerID <- paste0(host, '-listener-', Sys.getpid())
    if(logFileDir == 'stdout') {
        logFile = 'stdout'
    } else {
        logFile = paste0(listenerID, '.log')
    }

    Rbunyan::bunyanSetLog(level = logLevel, memlines = 0, logpath = logFileDir, logfile = logFile)
    Rbunyan::bunyanLog.info(
        sprintf(
            "Started listener on host %s.",
            listenerHost
        )
    )

    # Redis needs two connections. One for subscribing and one for publishing, popping, and pushing.
    # Save their references globally so they can be easily accessed anywhere
    # TODO: Try to find a way to pass references around so they do not have to be in global variables
    tryCatch(
        {
            outputConn <<- rredis::redisConnect(host = host, port = port, returnRef = T)
            subscribeConn <<- rredis::redisConnect(host = host, port = port, returnRef = T)
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


    # Define the callbacks
    channelNames <- defineChannels(channels, globalEnvironment)

    tryCatch(
        {
            rredis::redisSubscribe(channelNames)
        },
        error = function(e) {
            sprintf(
                "An error occurred while subscribing to channels %s: %s",
                paste(channelNames, collapse = ","),
                e
            )
            stop(e)
        }
    )

    while(1) {
        # TODO: Explore why the error is not being suppressed inside the callback
        try(rredis::redisMonitorChannels())
    }
}