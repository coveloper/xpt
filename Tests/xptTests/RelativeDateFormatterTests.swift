import Testing
import Foundation
@testable import xptCore

struct RelativeDateFormatterTests {

    @Test func justNow() {
        let now = Date()
        let formatter = RelativeDateFormatter(now: now)
        let date = now.addingTimeInterval(-30)
        #expect(formatter.string(from: date) == "just now")
    }

    @Test func justNowBoundary() {
        let now = Date()
        let formatter = RelativeDateFormatter(now: now)
        // 59 seconds = still "just now"
        let date = now.addingTimeInterval(-59)
        #expect(formatter.string(from: date) == "just now")
    }

    @Test func oneMinuteAgo() {
        let now = Date()
        let formatter = RelativeDateFormatter(now: now)
        let date = now.addingTimeInterval(-60)
        #expect(formatter.string(from: date) == "1 minute ago")
    }

    @Test func multipleMinutesAgo() {
        let now = Date()
        let formatter = RelativeDateFormatter(now: now)
        let date = now.addingTimeInterval(-300) // 5 minutes
        #expect(formatter.string(from: date) == "5 minutes ago")
    }

    @Test func oneHourAgo() {
        let now = Date()
        let formatter = RelativeDateFormatter(now: now)
        let date = now.addingTimeInterval(-3600)
        #expect(formatter.string(from: date) == "1 hour ago")
    }

    @Test func multipleHoursAgo() {
        let now = Date()
        let formatter = RelativeDateFormatter(now: now)
        let date = now.addingTimeInterval(-7200) // 2 hours
        #expect(formatter.string(from: date) == "2 hours ago")
    }

    @Test func yesterday() {
        let now = Date()
        let formatter = RelativeDateFormatter(now: now)
        let date = now.addingTimeInterval(-86400) // exactly 1 day
        #expect(formatter.string(from: date) == "yesterday")
    }

    @Test func twoDaysAgo() {
        let now = Date()
        let formatter = RelativeDateFormatter(now: now)
        let date = now.addingTimeInterval(-172800) // 2 days
        #expect(formatter.string(from: date) == "2 days ago")
    }

    @Test func sevenDaysAgo() {
        let now = Date()
        let formatter = RelativeDateFormatter(now: now)
        let date = now.addingTimeInterval(-7 * 86400)
        #expect(formatter.string(from: date) == "7 days ago")
    }
}
