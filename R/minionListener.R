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
#' @export
#'
#' @param host The name or ip address of the redis server.
#' @param port The port the redis server is running on.
#'

minionListener <- function(host, port, channels) {

}