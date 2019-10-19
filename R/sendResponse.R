#' A function that takes a connection, a location, a status, and a response and send the response.
#'
#' \code{sendResponse} takes the required inputs for a response, formats them appropriately, and
#' then sends the response.
#'
#' The response that will be sent back is the original `job` with the addition of the `status`
#' property and one of the following two properties: `error` or `results`. If `status` is either
#' 'failed' or 'catastrophic', then `response` will be placed in the `error` property. If `status`
#' is 'succeeded' then `response` will be placed in the `response` property.
#'
#' The 'failed' status should be used when the error occurred while executing the job and was
#' handled. The 'catastrophic' status should be used whenever an unhandled error that trips the
#' final try-catch occurs.
#'
#' @import redux jsonlite
#'
#' @param conn An open redux hiredis connection.
#' @param queue A string giving the name of the queue where the response will be sent.
#' @param status One of the following strings: "succeeded", "failed", or "catastrophic".
#' @param job The job that was used to generate `result`.
#' @param response The result of executing the job.
#' @param useJSON Flag specifying whether messages are in JSON format. Defaults to false.

sendResponse <- function(conn, queue, status = c('succeeded', 'failed', 'catastrophic'), job,
    response, useJSON = F) {
    status <- match.arg(status)
    job$status <- status
    if(status == 'succeeded') {
        job$results <- response
    } else {
        job$error <- response
    }
    if(useJSON) {
        job <- jsonlite::toJSON(job, auto_unbox = T, digits = NA)
    } else {
        job <- redux::object_to_bin(job)
    }
    conn$LPUSH(queue, job)
}