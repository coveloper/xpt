import Testing
import Foundation
@testable import xptCore

struct StorageManagerTests {

    // MARK: - sanitize / unsanitize

    @Test func sanitizeSlash() {
        #expect(StorageManager.sanitize("feature/login") == "feature%2Flogin")
    }

    @Test func sanitizePercent() {
        #expect(StorageManager.sanitize("foo%bar") == "foo%25bar")
    }

    @Test func sanitizePercentThenSlash() {
        #expect(StorageManager.sanitize("foo%2Fbar") == "foo%252Fbar")
    }

    @Test func sanitizeMultipleSlashes() {
        #expect(StorageManager.sanitize("a/b/c") == "a%2Fb%2Fc")
    }

    @Test func sanitizeEmpty() {
        #expect(StorageManager.sanitize("") == "")
    }

    @Test func sanitizePlainName() {
        #expect(StorageManager.sanitize("main") == "main")
    }

    @Test func unsanitizeRoundTrip() {
        let branches = ["main", "feature/login", "bugfix/crash-on-launch", "foo%bar", "a/b/c", ""]
        for branch in branches {
            #expect(StorageManager.unsanitize(StorageManager.sanitize(branch)) == branch)
        }
    }

    @Test func unsanitizeEncodedSlash() {
        #expect(StorageManager.unsanitize("feature%2Flogin") == "feature/login")
    }

    // MARK: - normalizeRemoteURL

    @Test func normalizeStripsTrailingGit() {
        #expect(StorageManager.normalizeRemoteURL("https://github.com/user/repo.git") == "https://github.com/user/repo")
    }

    @Test func normalizeLowercases() {
        #expect(StorageManager.normalizeRemoteURL("https://GitHub.COM/User/Repo") == "https://github.com/user/repo")
    }

    @Test func normalizeNoGitSuffix() {
        #expect(StorageManager.normalizeRemoteURL("https://github.com/user/repo") == "https://github.com/user/repo")
    }

    @Test func normalizeLowercasesAndStripsGit() {
        #expect(StorageManager.normalizeRemoteURL("https://GitHub.COM/User/Repo.git") == "https://github.com/user/repo")
    }

    // MARK: - validateBranchName

    @Test func validateEmptyBranchThrows() {
        #expect(throws: StorageError.self) {
            try StorageManager.validateBranchName("")
        }
    }

    @Test func validateNullByteBranchThrows() {
        #expect(throws: StorageError.self) {
            try StorageManager.validateBranchName("main\0bad")
        }
    }

    @Test func validateNewlineBranchThrows() {
        #expect(throws: StorageError.self) {
            try StorageManager.validateBranchName("main\nbad")
        }
    }

    @Test func validateNormalBranchSucceeds() throws {
        try StorageManager.validateBranchName("main")
        try StorageManager.validateBranchName("feature/login")
        try StorageManager.validateBranchName("bugfix/crash-on-launch")
        try StorageManager.validateBranchName("branch-with-percent%25")
    }

    // MARK: - validateXML

    @Test func validateXMLEmptyDataThrows() {
        #expect(throws: StorageError.self) {
            try StorageManager.validateXML(data: Data())
        }
    }

    @Test func validateXMLNonXMLThrows() {
        let garbage = Data([0xFF, 0xFE, 0x00, 0x01])
        #expect(throws: StorageError.self) {
            try StorageManager.validateXML(data: garbage)
        }
    }

    @Test func validateXMLNonBucketRootThrows() {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0"><dict></dict></plist>
        """.data(using: .utf8)!
        #expect(throws: StorageError.self) {
            try StorageManager.validateXML(data: plist)
        }
    }

    @Test func validateXMLValidBucketSucceeds() throws {
        let bucket = """
        <?xml version="1.0" encoding="UTF-8"?>
        <Bucket type="1" version="2.0"></Bucket>
        """.data(using: .utf8)!
        try StorageManager.validateXML(data: bucket)
    }
}
