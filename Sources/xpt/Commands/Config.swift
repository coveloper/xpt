import ArgumentParser
import Foundation

struct Config: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Display or edit the repo-level .xpt configuration."
    )

    @Option(name: .long, help: "Set a config value, e.g. --set onEmptyBranch=preserve")
    var set: String?

    func run() throws {
        let repoRoot = try GitUtilities.repoRoot()
        var config = try RepoConfig.load(from: repoRoot)

        if let assignment = set {
            // Parse key=value
            let parts = assignment.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else {
                throw ConfigError.invalidFormat(assignment)
            }
            let key = String(parts[0])
            let value = String(parts[1])

            try config.set(key: key, value: value)
            try config.save(to: repoRoot)
            print("xpt: Set \(key) = \(value)")
        } else {
            // Display current config
            let configPath = RepoConfig.configURL(repoRoot: repoRoot)
            if FileManager.default.fileExists(atPath: configPath.path) {
                print("Config at \(configPath.path):\n")
            } else {
                print("No .xpt config file found. Using defaults:\n")
            }
            print(try config.prettyPrinted())
        }
    }
}
