result <- list(
    x = 1,
    y = 'string',
    z = F
)
job <- list(
    package = 'myPackage',
    func = 'myFunction',
    parameters = list(
        x = 1,
        y = 'string',
        z = T
    ),
    resultsQueue = 'myResultsQueue',
    errorQueue = 'myErrorQueue'
)

test_that('success responses can be sent and are of appropriate structure using internal serialization', {
    skipIfNoRedis()
    reduxConn <- testReduxConnection()

    cleanQueue(reduxConn, 'testThatQueue')

    rminions:::sendResponse(
        reduxConn,
        'testThatQueue',
        'succeeded',
        job,
        result
    )
    expectedResponse <- job
    expectedResponse$status <- 'succeeded'
    expectedResponse$results <- result
    binaryMessage <- reduxConn$RPOP('testThatQueue')
    message <- redux::bin_to_object(binaryMessage)
    expect_identical(
        message,
        expectedResponse
    )
})

test_that('failure responses can be sent and are of appropriate structure using internal serialization', {
    skipIfNoRedis()
    reduxConn <- testReduxConnection()

    cleanQueue(reduxConn, 'testThatQueue')

    rminions:::sendResponse(
        reduxConn,
        'testThatQueue',
        'failed',
        job,
        result
    )
    expectedResponse <- job
    expectedResponse$status <- 'failed'
    expectedResponse$error <- result
    binaryMessage <- reduxConn$RPOP('testThatQueue')
    message <- redux::bin_to_object(binaryMessage)
    expect_identical(
        message,
        expectedResponse
    )
})

test_that('unhandled error responses can be sent and are of appropriate structure using internal serialization', {
    skipIfNoRedis()
    reduxConn <- testReduxConnection()

    cleanQueue(reduxConn, 'testThatQueue')

    rminions:::sendResponse(
        reduxConn,
        'testThatQueue',
        'catastrophic',
        job,
        result
    )
    expectedResponse <- job
    expectedResponse$status <- 'catastrophic'
    expectedResponse$error <- result
    binaryMessage <- reduxConn$RPOP('testThatQueue')
    message <- redux::bin_to_object(binaryMessage)
    expect_identical(
        message,
        expectedResponse
    )
})

test_that('success responses can be sent and are of appropriate structure using JSON', {
    skipIfNoRedis()
    reduxConn <- testReduxConnection()

    cleanQueue(reduxConn, 'testThatQueue')

    rminions:::sendResponse(
        reduxConn,
        'testThatQueue',
        'succeeded',
        job,
        result,
        useJSON = T
    )
    expectedResponse <- job
    expectedResponse$status <- 'succeeded'
    expectedResponse$results <- result
    expectedResponse <- as.character(
        jsonlite::toJSON(expectedResponse, auto_unbox = T, digits = NA)
    )
    jsonMessage <- reduxConn$RPOP('testThatQueue')
    expect_identical(
        jsonMessage,
        expectedResponse
    )
})

test_that('failure responses can be sent and are of appropriate structure using JSON', {
    skipIfNoRedis()
    reduxConn <- testReduxConnection()

    cleanQueue(reduxConn, 'testThatQueue')

    rminions:::sendResponse(
        reduxConn,
        'testThatQueue',
        'failed',
        job,
        result,
        useJSON = T
    )
    expectedResponse <- job
    expectedResponse$status <- 'failed'
    expectedResponse$error <- result
    expectedResponse <- as.character(
        jsonlite::toJSON(expectedResponse, auto_unbox = T, digits = NA)
    )
    jsonMessage <- reduxConn$RPOP('testThatQueue')
    expect_identical(
        jsonMessage,
        expectedResponse
    )
})

test_that('unhandled error responses can be sent and are of appropriate structure using JSON', {
    skipIfNoRedis()
    reduxConn <- testReduxConnection()

    cleanQueue(reduxConn, 'testThatQueue')

    rminions:::sendResponse(
        reduxConn,
        'testThatQueue',
        'catastrophic',
        job,
        result,
        useJSON = T
    )
    expectedResponse <- job
    expectedResponse$status <- 'catastrophic'
    expectedResponse$error <- result
    expectedResponse <- as.character(
        jsonlite::toJSON(expectedResponse, auto_unbox = T, digits = NA)
    )
    jsonMessage <- reduxConn$RPOP('testThatQueue')
    expect_identical(
        jsonMessage,
        expectedResponse
    )
})