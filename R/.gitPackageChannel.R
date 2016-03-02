#' A function that defines a channel and handles messages for installing Git packages.
#'
#' \code{.gitPackageChannel} is a function that should be passed to \code{minionListener}
#' whenever you want to add a listener and handler for installing packages from a Git
#' repository. It tells the listener what channel to listen on and defines a callback
#' for handling any messages on this channel.
#'
#' The handler for \code{.gitPackageChannel} expects package installation messages to be
#' lists with one required key and two optional keys. The required key is \code{url},
#' and the optional keys are \code{subdir} and \code{branch}. For more information on
#' these values, see the documentation for \code{install_git} from the \code{devtools}
#' package.
#'
#' @export
#'
#' @param channel The channel to listen for git package installation messages. Defaults
#'   to \code{gitPackage}.

.gitPackageChannel <- function(channel = "gitPackage") {
    callback <- function(message) {
        install_git(
            url = message$url,
            subdir = message$subdir,
            branch = message$branch
        )
    }
    return(
        list(
            channel = channel,
            callback = callback
        )
    )
}