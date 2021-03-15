import XCTest

import gitlab_ci_to_xcode_serverTests

var tests = [XCTestCaseEntry]()
tests += gitlab_ci_to_xcode_serverTests.allTests()
XCTMain(tests)
