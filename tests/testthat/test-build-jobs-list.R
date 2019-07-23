context('build-jobs-list')

test_that('job bundles are built correctly', {
  expect_equal(
    buildJobsList(func = 'functionName', resultsQueue = 'resultsQueue', errorQueue = 'errorQueue'),
    list(
      Function = 'functionName',
      Parameters = list(),
      ResultsQueue = 'resultsQueue',
      ErrorQueue = 'errorQueue'
    )
  )
  
  expect_equal(
    buildJobsList(
      func = 'functionName',
      x = 1,
      y ='string',
      z = T,
      resultsQueue = 'resultsQueue',
      errorQueue = 'errorQueue'
    ),
    list(
      Function = 'functionName',
      Parameters = list(x = 1, y = 'string', z = T),
      ResultsQueue = 'resultsQueue',
      ErrorQueue = 'errorQueue'
    )
  )
})