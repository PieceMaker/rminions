#' A function that defines the channel callbacks and returns the channels to listen on.
#'
#' \code{defineChannels} takes a list of functions defining channels. It creates the
#' appropriate callbacks on the global environment and then returns the names of the
#' channels to be passed later to \code{redisSubscribe}.
#'
#' This function should be used if you plan on manually subscribing to and monitoring
#' channels. If you wish to automatically subscribe to the channels after they are
#' defined use \code{minionListener}.
#'
#' @import plyr
#'
#' @export
#'
#' @param channels A list of functions defining channels to subscribe to with
#'   corresponding callbacks.
#' @param envir The environment to assign the callbacks in.

defineChannels <- function(channels, envir) {
    # Define the callbacks
    channelNames <- plyr::laply(.data = channels, .fun = defineCallback, envir = envir)

    return(channelNames)
}