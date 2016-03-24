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
#' @export
#'
#' @import devtools jsonlite rredis R.utils
#'
#' @param channel The channel to listen for git package installation messages. Defaults
#'   to \code{gitHubPackage}.
#' @param errorChannel The channel to publish errors on if/when they occur. Defaults to
#'   \code{listenerErrors}.

gitHubPackageChannel <- function(channel = "gitHubPackage", errorChannel = "listenerErrors") {
    callback <- function(message) {
        #Message must be passed in as JSON from jsonlite
        message <- unserializeJSON(message)
        listenerHost <- as.character(System$getHostname())
        tryCatch(
            install_github(
                repo = message$repo,
                subdir = message$subdir,
                username = message$username
            ),
            error = function(e) {
                e <- sprintf("An error occurred processing job on channel '%s' on listener for server '%s': %s",
                    channel,
                    listenerHost,
                    e
                )
                redisSetContext(outputConn)
                redisPublish(errorChannel, e)
                redisSetContext(subscribeConn)
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