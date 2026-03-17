import Testing
@testable import xptCore

struct XcodeUtilitiesTests {

    // MARK: - escapeForAppleScript

    @Test func noQuotesPassThrough() {
        let result = XcodeUtilities.escapeForAppleScript("/path/to/MyApp.xcworkspace")
        #expect(result == "\"/path/to/MyApp.xcworkspace\"")
    }

    @Test func singleQuoteIsSplit() {
        let result = XcodeUtilities.escapeForAppleScript("/path/with\"quote")
        #expect(result == "\"/path/with\" & quote & \"quote\"")
    }

    @Test func multipleQuotesAllReplaced() {
        let result = XcodeUtilities.escapeForAppleScript("a\"b\"c")
        #expect(result == "\"a\" & quote & \"b\" & quote & \"c\"")
    }

    @Test func emptyStringWrapped() {
        let result = XcodeUtilities.escapeForAppleScript("")
        #expect(result == "\"\"")
    }
}
