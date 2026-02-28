import ArgumentParser

struct Restore: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Restore breakpoints for the current (or named) branch."
    )

    @Option(name: .long, help: "Branch name to restore from. Defaults to current branch.")
    var branch: String?

    func run() throws {
        print("restore: not yet implemented")
    }
}
