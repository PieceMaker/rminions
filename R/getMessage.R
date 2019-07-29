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

getMessage <- function(conn, queue, useJSON = F) {
    message <- conn$RPOP(queue)
    if(useJSON) {
        message <- jsonlite::fromJSON(message)
    } else {
        message <- redux::bin_to_object(message)
    }
    return(message)
}