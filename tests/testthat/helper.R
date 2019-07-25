skipIfNoRedis <- function() {
  if(!redux::redis_available()) {
    testthat::skip("Redis is not available")
  }
}

testReduxConnection <- function() {
  skipIfNoRedis()
  return(redux::hiredis())
}

testRRedisConnection <- function() {
  skipIfNoRedis()
  conn <- rredis::redisConnect(returnRef = T)
  return(conn)
}

cleanQueue <- function(reduxConn, queue) {
  reduxConn$DEL(queue)
  expect_equal(reduxConn$LLEN('testThatQueue'), 0)
}