import Foundation

public struct RepoConfig: Codable {
    public var project: String?
    public var onEmptyBranch: OnEmptyBranch?

    public enum OnEmptyBranch: String, Codable {
        case clear
        case preserve
    }

    public init() {}

    // Effective value with default applied
    public var effectiveOnEmptyBranch: OnEmptyBranch {
        onEmptyBranch ?? .clear
    }

    // MARK: - Load / Save

    private static var prettyEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    public static func load(from repoRoot: URL) throws -> RepoConfig {
        let url = configURL(repoRoot: repoRoot)
        guard let data = try? Data(contentsOf: url) else {
            return RepoConfig()
        }
        return try JSONDecoder().decode(RepoConfig.self, from: data)
    }

    public func save(to repoRoot: URL) throws {
        let url = RepoConfig.configURL(repoRoot: repoRoot)
        let data = try RepoConfig.prettyEncoder.encode(self)
        try data.write(to: url, options: .atomic)
    }

    public static func configURL(repoRoot: URL) -> URL {
        repoRoot.appendingPathComponent(".xpt")
    }

    // MARK: - Key-value setting

    public mutating func set(key: String, value: String) throws {
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

    public func prettyPrinted() throws -> String {
        let data = try RepoConfig.prettyEncoder.encode(self)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

public enum ConfigError: Error, CustomStringConvertible {
    case unknownKey(String)
    case invalidValue(key: String, value: String, valid: [String])
    case invalidFormat(String)

    public var description: String {
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
