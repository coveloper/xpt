import ArgumentParser

struct Save: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Save current breakpoints for the current (or named) branch."
    )

    @Option(name: .long, help: "Branch name to save as. Defaults to current branch.")
    var branch: String?

    func run() throws {
        print("save: not yet implemented")
    }
}
