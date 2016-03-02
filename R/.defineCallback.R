#' An internal function that takes a channel definition and creates the callback.
#'
#' The \code{redisSubscribe} function expects callbacks to a function with the same
#' name as the subscribed channel. \code{.defineCallback} takes the callback
#' returned from a channel definition and assigns it to the correct function name
#' so \code{redisSubscribe} can access it.
#'
#' @param channelDef A list containing \code{channel} and \code{callback}, returned
#'   from a channel definition function.

.defineCallback <- function(channelDef) {
    #TODO: find correct environment for assignment; keep in mind this will hopefully be in an apply
    assign(channelDef$channel, channelDef$callback)
}