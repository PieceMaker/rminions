queueJobs <- function(iter, func, ..., resultsKey, jobsQueue = "jobsqueue") {
    upload <- apply(
        iter,
        1, #apply to rows
        buildList,
        func = func,
        resultsKey = resultsKey,
        ...
    )

    lapply(upload, redisRPush, key = jobsQueue)
}