#' An internal function that takes a channel definition and creates the callback.
#'
#' The \code{redisSubscribe} function expects callbacks to a function with the same
#' name as the subscribed channel. \code{.defineCallback} takes the callback
#' returned from a channel definition and assigns it to the correct function name
#' so \code{redisSubscribe} can access it.
#'
#' @param channelDef A list containing \code{channel} and \code{callback}, returned
#'   from a channel definition function.
#' @param envir An environment object

.defineCallback <- function(channelDef, envir) {
    #TODO: test to see if this method of passing an environment solves the likely problem
    assign(channelDef$channel, channelDef$callback, envir = envir)
}