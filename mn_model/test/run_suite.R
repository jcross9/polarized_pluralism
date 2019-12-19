library(RUnit)

TESTING <- TRUE

# init testing suite
test.suite <- defineTestSuite("mn_model",
                              dirs = file.path("./lib/mn_model/"),
                              testFileRegexp = 'test.*.R$')
test.result <- runTestSuite(test.suite)
printTextProtocol(test.result)