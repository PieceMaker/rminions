resultList <- list(
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
resultJSON <- as.character(
  jsonlite::toJSON(resultList, auto_unbox = T, digits = NA)
)

test_that('messages can be sent and are of appropriate structure using internal serialization', {
  skipIfNoRedis()
  reduxConn <- testReduxConnection()
  
  cleanQueue(reduxConn, 'testThatQueue')
  
  sendMessage(
    reduxConn,
    jobsQueue = 'testThatQueue',
    package = 'myPackage',
    func = 'myFunction',
    x = 1,
    y = 'string',
    z = T,
    resultsQueue = 'myResultsQueue',
    errorQueue = 'myErrorQueue',
    useJSON = F
  )
  binaryMessage <- reduxConn$RPOP('testThatQueue')
  message <- redux::bin_to_object(binaryMessage)
  expect_true(identical(
    message,
    resultList
  ))
})

test_that('messages can be sent and are of appropriate structure using JSON', {
  skipIfNoRedis()
  reduxConn <- testReduxConnection()
  
  cleanQueue(reduxConn, 'testThatQueue')
  
  sendMessage(
    reduxConn,
    jobsQueue = 'testThatQueue',
    package = 'myPackage',
    func = 'myFunction',
    x = 1,
    y = 'string',
    z = T,
    resultsQueue = 'myResultsQueue',
    errorQueue = 'myErrorQueue',
    useJSON = T
  )
  message <- reduxConn$RPOP('testThatQueue')
  expect_equal(
    message,
    resultJSON
  )
})