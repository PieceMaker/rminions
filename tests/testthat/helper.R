skipIfNoRedis <- function() {
  if(!redux::redis_available()) {
    testthat::skip("Redis is not available")
  }
}

testReduxConnection <- function() {
  skipIfNoRedis()
  return(redux::hiredis())
}

cleanQueue <- function(reduxConn, queue) {
  reduxConn$DEL(queue)
  expect_equal(reduxConn$LLEN('testThatQueue'), 0)
}