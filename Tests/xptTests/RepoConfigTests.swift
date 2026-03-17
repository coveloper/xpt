import Testing
import Foundation
@testable import xptCore

struct RepoConfigTests {

    // MARK: - effectiveOnEmptyBranch defaults

    @Test func defaultsToClear() {
        let config = RepoConfig()
        #expect(config.effectiveOnEmptyBranch == .clear)
    }

    @Test func preserveWhenSet() throws {
        var config = RepoConfig()
        try config.set(key: "onEmptyBranch", value: "preserve")
        #expect(config.effectiveOnEmptyBranch == .preserve)
    }

    @Test func invalidValueDefaultsToClear() {
        var config = RepoConfig()
        // Setting an invalid value should throw, leaving config unchanged
        #expect(throws: ConfigError.self) {
            try config.set(key: "onEmptyBranch", value: "unknown")
        }
        #expect(config.effectiveOnEmptyBranch == .clear)
    }

    // MARK: - JSON round-trip

    @Test func jsonRoundTrip() throws {
        var config = RepoConfig()
        try config.set(key: "project", value: "MyApp.xcworkspace")
        try config.set(key: "onEmptyBranch", value: "preserve")

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(RepoConfig.self, from: data)

        #expect(decoded.project == "MyApp.xcworkspace")
        #expect(decoded.onEmptyBranch == .preserve)
    }

    @Test func jsonRoundTripNilProject() throws {
        let config = RepoConfig()
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(RepoConfig.self, from: data)
        #expect(decoded.project == nil)
        #expect(decoded.onEmptyBranch == nil)
    }

    // MARK: - load from missing file

    @Test func loadMissingFileReturnsDefaults() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let config = try RepoConfig.load(from: tmp)
        #expect(config.project == nil)
        #expect(config.onEmptyBranch == nil)
        #expect(config.effectiveOnEmptyBranch == .clear)
    }

    // MARK: - set() validation

    @Test func setUnknownKeyThrows() {
        var config = RepoConfig()
        #expect(throws: ConfigError.self) {
            try config.set(key: "unknownKey", value: "value")
        }
    }

    @Test func setProjectValue() throws {
        var config = RepoConfig()
        try config.set(key: "project", value: "MyApp.xcworkspace")
        #expect(config.project == "MyApp.xcworkspace")
    }
}
