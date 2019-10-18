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
sentBinary <- redux::object_to_bin(result)
sentJSON <- as.character(
  jsonlite::toJSON(result, auto_unbox = T, digits = NA)
)

test_that('binary messages that are pulled from the queue are appropriately deserialized and returned to the user', {
  skipIfNoRedis()
  reduxConn <- testReduxConnection()
  cleanQueue(reduxConn, 'testThatQueue')
  
  reduxConn$RPUSH('testThatQueue', sentBinary)
  message <- getMessage(conn = reduxConn, queue = 'testThatQueue', useJSON = F)
  expect_equal(
    message,
    result
  )
})

test_that('JSON messages that are pulled from the queue are appropriately deserialized and returned to the user', {
  skipIfNoRedis()
  reduxConn <- testReduxConnection()
  cleanQueue(reduxConn, 'testThatQueue')
  
  reduxConn$RPUSH('testThatQueue', sentJSON)
  message <- getMessage(conn = reduxConn, queue = 'testThatQueue', useJSON = T)
  expect_equal(
    message,
    result
  )
})

test_that('error is thrown when no messages are in queue', {
  skipIfNoRedis()
  reduxConn <- testReduxConnection()
  cleanQueue(reduxConn, 'emptyQueue')

  expect_error(
    getMessage(conn = reduxConn, queue = 'emptyQueue'),
    'No message found in queue'
  )
})