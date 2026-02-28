import ArgumentParser

struct Delete: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Remove the saved breakpoint set for a branch."
    )

    @Argument(help: "The branch whose saved breakpoints should be deleted.")
    var branch: String

    func run() throws {
        print("delete: not yet implemented")
    }
}
