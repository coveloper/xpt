import Testing
@testable import xptCore

struct HookTests {

    // MARK: - parsePreviousBranch(fromReflogEntry:excluding:)

    @Test func parseSimpleCheckout() {
        let entry = "checkout: moving from main to feature/foo"
        let result = Hook.parsePreviousBranch(fromReflogEntry: entry, excluding: "feature/foo")
        #expect(result == "main")
    }

    @Test func parseCheckoutWithSlashInPrevBranch() {
        let entry = "checkout: moving from feature/login to main"
        let result = Hook.parsePreviousBranch(fromReflogEntry: entry, excluding: "main")
        #expect(result == "feature/login")
    }

    @Test func parseWhenPrevEqualsCurrentReturnsNil() {
        // Same branch on both sides (edge case) - excluding matches prev
        let entry = "checkout: moving from main to main"
        let result = Hook.parsePreviousBranch(fromReflogEntry: entry, excluding: "main")
        #expect(result == nil)
    }

    @Test func malformedEntryReturnsNil() {
        let entry = "commit: something happened"
        let result = Hook.parsePreviousBranch(fromReflogEntry: entry, excluding: "main")
        #expect(result == nil)
    }

    @Test func emptyEntryReturnsNil() {
        let result = Hook.parsePreviousBranch(fromReflogEntry: "", excluding: "main")
        #expect(result == nil)
    }

    @Test func parseCheckoutWithBranchContainingSlashes() {
        let entry = "checkout: moving from feature/a/b/c to main"
        let result = Hook.parsePreviousBranch(fromReflogEntry: entry, excluding: "main")
        #expect(result == "feature/a/b/c")
    }
}
