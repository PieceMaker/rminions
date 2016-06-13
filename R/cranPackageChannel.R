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
#' @import jsonlite rredis R.utils
#'
#' @export
#'
#' @param channel The channel to listen for cran package installation messages. Defaults
#'   to \code{cranPackage}.
#' @param successChannel The channel to publish success messages after CRAN package
#'   has been successfully installed. Defaults to \code{listenerSuccesses}.
#' @param errorChannel The channel to publish errors on if/when they occur. Defaults to
#'   \code{listenerErrors}.

cranPackageChannel <- function(channel = "cranPackage", successChannel = "listenerSuccesses", errorChannel = "listenerErrors") {
    callback <- function(message) {
        #Message must be passed in as JSON from jsonlite
        message <- jsonlite::unserializeJSON(message)
        listenerHost <- as.character(R.utils::System$getHostname())
        tryCatch(
            {
                install.packages(message$packageName)
                successMessage <- sprintf(
                    "Successfully installed CRAN package '%s' on server '%s'.",
                    message$packageName,
                    listenerHost
                )
                rredis::redisSetContext(outputConn)
                rredis::redisPublish(successChannel, successMessage)
                rredis::redisSetContext(subscribeConn)
            },
            error = function(errorMessage) {
                errorMessage <- sprintf(
                    "An error occurred processing job on channel '%s' on listener for server '%s': %s",
                    channel,
                    listenerHost,
                    errorMessage
                )
                rredis::redisSetContext(outputConn)
                rredis::redisPublish(errorChannel, errorMessage)
                rredis::redisSetContext(subscribeConn)
            }
        )
    }
    return(
        list(
            channel = channel,
            callback = callback
        )
    )
}