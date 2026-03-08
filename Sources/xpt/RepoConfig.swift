import Foundation

struct RepoConfig: Codable {
    var project: String?
    var onEmptyBranch: OnEmptyBranch?

    enum OnEmptyBranch: String, Codable {
        case clear
        case preserve
    }

    // Effective value with default applied
    var effectiveOnEmptyBranch: OnEmptyBranch {
        onEmptyBranch ?? .clear
    }

    // MARK: - Load / Save

    static func load(from repoRoot: URL) throws -> RepoConfig {
        let url = configURL(repoRoot: repoRoot)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return RepoConfig()
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(RepoConfig.self, from: data)
    }

    func save(to repoRoot: URL) throws {
        let url = RepoConfig.configURL(repoRoot: repoRoot)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: url, options: .atomic)
    }

    static func configURL(repoRoot: URL) -> URL {
        repoRoot.appendingPathComponent(".xpt")
    }

    // MARK: - Key-value setting

    mutating func set(key: String, value: String) throws {
        switch key {
        case "project":
            project = value
        case "onEmptyBranch":
            guard let parsed = OnEmptyBranch(rawValue: value) else {
                throw ConfigError.invalidValue(key: key, value: value, valid: ["clear", "preserve"])
            }
            onEmptyBranch = parsed
        default:
            throw ConfigError.unknownKey(key)
        }
    }

    // MARK: - Display

    func prettyPrinted() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

enum ConfigError: Error, CustomStringConvertible {
    case unknownKey(String)
    case invalidValue(key: String, value: String, valid: [String])
    case invalidFormat(String)

    var description: String {
        switch self {
        case .unknownKey(let key):
            return "Unknown config key '\(key)'. Valid keys: project, onEmptyBranch"
        case .invalidValue(let key, let value, let valid):
            return "Invalid value '\(value)' for '\(key)'. Valid values: \(valid.joined(separator: ", "))"
        case .invalidFormat(let s):
            return "Invalid format '\(s)'. Expected key=value"
        }
    }
}
