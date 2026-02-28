import ArgumentParser

struct Setup: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Install the post-checkout git hook into the current repo."
    )

    func run() throws {
        print("setup: not yet implemented")
    }
}
