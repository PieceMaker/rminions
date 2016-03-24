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
#' @export
#'
#' @import plyr rredis R.utils
#'
#' @param host The name or ip address of the redis server.
#' @param channels A list of functions defining channels to subscribe to with
#'   corresponding callbacks.
#' @param port The port the redis server is running on. Defaults to 6379.
#' @param logging A boolean to enable or disable logging to a file on the system. Defaults
#'   to \code{true}.
#' @param logFileDir A string giving the directory to store worker log files if logging is
#'   enabled.

minionListener <- function(host, channels, port = 6379, logging = T, logFileDir = "/var/log/R/") {
    globalEnvironment <- globalenv()

    listenerHost <- as.character(System$getHostname())
    listenerID <- paste0(host, '-listener-', Sys.getpid())
    if(logging) {
        logFilePath <- paste0(logFileDir, listenerID, '.log')
        logFile <- file(logFilePath, open = 'a')
        sink(logFile, type = 'message')
    }

    redisConnect(host = host, port = port)

    # Define the callbacks
    channelNames <- defineChannels(channels, globalEnvironment)

    redisSubscribe(channelNames)

    while(1) {
        redisMonitorChannels()
    }
}