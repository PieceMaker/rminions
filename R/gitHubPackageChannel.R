#' A function that defines a channel and handles messages for installing GitHub packages.
#'
#' \code{gitHubPackageChannel} is a function that should be passed to
#' \code{minionListener} whenever you want to add a listener and handler for installing
#' packages from a GitHub repository. It tells the listener what channel to listen on and
#' defines a callback for handling any messages on this channel.
#'
#' The handler for \code{gitHubPackageChannel} expects package installation messages to be
#' lists with one required key and two optional keys. The required key is \code{repo},
#' and the optional keys are \code{subdir} and \code{username}. For more information on
#' these values, see the documentation for \code{install_github} from the \code{devtools}
#' package.
#'
#' @import devtools jsonlite rredis R.utils
#'
#' @export
#'
#' @param channel The channel to listen for git package installation messages. Defaults
#'   to \code{gitHubPackage}.
#' @param successChannel The channel to publish success messages after GitHub package
#'   has been successfully installed. Defaults to \code{listenerSuccesses}.
#' @param errorChannel The channel to publish errors on if/when they occur. Defaults to
#'   \code{listenerErrors}.

gitHubPackageChannel <- function(channel = "gitHubPackage", successChannel = "listenerSuccesses", errorChannel = "listenerErrors") {
    callback <- function(message) {
        #Message must be passed in as JSON from jsonlite
        message <- jsonlite::unserializeJSON(message)
        listenerHost <- as.character(R.utils::System$getHostname())
        tryCatch(
            {
                devtools::install_github(
                    repo = message$repo,
                    subdir = message$subdir,
                    username = message$username
                )
                successMessage <- sprintf(
                    "Successfully installed GitHub package from '%s' on server '%s'.",
                    message$repo,
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