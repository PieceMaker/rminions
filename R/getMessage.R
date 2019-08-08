#' A function that takes a queue and a serialization type and returns the parsed message.
#'
#' \code{getMessage} takes a Redis connection, a string queue, and a boolean specifying
#' whether the serialization was JSON or not. It then gets the message from the queue,
#' parses it, and returns the parsed message.
#'
#' @import redux jsonlite
#'
#' @export
#'
#' @param conn An open redux hiredis connection.
#' @param queue A string giving the name of the queue to get the message from.
#' @param useJSON Flag specifying whether messages are in JSON format. Defaults to false.
#' @param blocking Flag specifying whether a blocking pop or regular pop will be performed
#'   when getting a message from the queue.

getMessage <- function(conn, queue, useJSON = F, blocking = F) {
    if(blocking) {
        message <- conn$BRPOP(queue, 0)[2][[1]]
    } else {
        message <- conn$RPOP(queue)
    }
    if(is.null(message)) {
        stop('No message found in queue')
    }
    if(useJSON) {
        message <- jsonlite::fromJSON(message)
    } else {
        message <- redux::bin_to_object(message)
    }
    return(message)
}