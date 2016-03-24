buildJobsList <- function(func, ..., resultsKey) {
    return(
        list(
            Function = func,
            Params = list(...),
            ResultsKey = resultsKey
        )
    )
}