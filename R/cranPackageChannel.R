#' A function that defines a channel and handles messages for installing CRAN packages.
#'
#' \code{cranPackageChannel} is a function that should be passed to \code{minionListener}
#' whenever you want to add a listener and handler for installing CRAN packages on a
#' minion server. It tells the listener what channel to listen on and defines a
#' callback for handling any messages on this channel.
#'
#' The handler for \code{cranPackageChannel} expects package installation messages to
#' be lists with one key, \code{packageName}, which should be a string containing the name
#' of the package to be installed. The handler then takes this string and installs the
#' package of that name from CRAN.
#'
#' @export
#'
#' @import jsonlite
#'
#' @param channel The channel to listen for cran package installation messages. Defaults
#'   to \code{cranPackage}.

cranPackageChannel <- function(channel = "cranPackage") {
    callback <- function(message) {
        #Message must be passed in as JSON from jsonlite
        message <- unserializeJSON(message)
        install.packages(message$packageName)
    }
    return(
        list(
            channel = channel,
            callback = callback
        )
    )
}