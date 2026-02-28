import ArgumentParser

struct Config: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Display or edit the repo-level .xmark configuration."
    )

    @Option(name: .long, help: "Set a config value, e.g. --set onEmptyBranch=preserve")
    var set: String?

    func run() throws {
        print("config: not yet implemented")
    }
}
