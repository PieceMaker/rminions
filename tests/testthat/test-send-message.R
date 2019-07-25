result <- list(
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

test_that('messages can be sent and are of appropriate structure using internal serialization', {
  skipIfNoRedis()
  reduxConn <- testReduxConnection()
  rredisConn <- testRRedisConnection()
  
  cleanQueue(reduxConn, 'testThatQueue')
  
  sendMessage(
    rredisConn,
    jobsQueue = 'testThatQueue',
    package = 'myPackage',
    func = 'myFunction',
    parameters = list(
      x = 1,
      y = 'string',
      z = T
    ),
    resultsQueue = 'myResultsQueue',
    errorQueue = 'myErrorQueue',
    useJSON = F
  )
  message <- redisRPop('testThatQueue')
  expect_true(identical(
    message,
    result
  ))
  
  redisClose(rredisConn)
})

test_that('messages can be sent and are of appropriate structure using JSON', {
  skipIfNoRedis()
  reduxConn <- testReduxConnection()
  rredisConn <- testRRedisConnection()
  
  cleanQueue(reduxConn, 'testThatQueue')
  
  sendMessage(
    rredisConn,
    jobsQueue = 'testThatQueue',
    package = 'myPackage',
    func = 'myFunction',
    parameters = list(
      x = 1,
      y = 'string',
      z = T
    ),
    resultsQueue = 'myResultsQueue',
    errorQueue = 'myErrorQueue',
    useJSON = T
  )
  message <- redisRPop('testThatQueue')
  expect_equal(
    message,
    jsonlite::toJSON(result)
  )
  
  redisClose(rredisConn)
})