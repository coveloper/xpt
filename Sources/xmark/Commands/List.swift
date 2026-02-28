import ArgumentParser

struct List: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "Show all saved breakpoint sets for this repo."
    )

    func run() throws {
        print("list: not yet implemented")
    }
}
