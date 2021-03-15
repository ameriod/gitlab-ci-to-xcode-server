import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(gitlab_ci_to_xcode_serverTests.allTests),
    ]
}
#endif
