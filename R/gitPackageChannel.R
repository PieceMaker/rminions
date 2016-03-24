#' A function that defines a channel and handles messages for installing Git packages.
#'
#' \code{gitPackageChannel} is a function that should be passed to \code{minionListener}
#' whenever you want to add a listener and handler for installing packages from a Git
#' repository. It tells the listener what channel to listen on and defines a callback
#' for handling any messages on this channel.
#'
#' The handler for \code{gitPackageChannel} expects package installation messages to be
#' lists with one required key and two optional keys. The required key is \code{url},
#' and the optional keys are \code{subdir} and \code{branch}. For more information on
#' these values, see the documentation for \code{install_git} from the \code{devtools}
#' package.
#'
#' @export
#'
#' @import devtools jsonlite rredis R.utils
#'
#' @param channel The channel to listen for git package installation messages. Defaults
#'   to \code{gitPackage}.
#' @param errorChannel The channel to publish errors on if/when they occur. Defaults to
#'   \code{listenerErrors}.

gitPackageChannel <- function(channel = "gitPackage", errorChannel = "listenerErrors") {
    callback <- function(message) {
        #Message must be passed in as JSON from jsonlite
        message <- unserializeJSON(message)
        listenerHost <- as.character(System$getHostname())
        tryCatch(
            install_git(
                url = message$url,
                subdir = message$subdir,
                branch = message$branch
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