import ArgumentParser

struct Hook: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "_hook",
        abstract: "Internal: called by the git post-checkout hook.",
        shouldDisplay: false
    )

    @Argument(help: "Hook name (e.g. post-checkout)")
    var hookName: String

    @Argument(help: "Previous HEAD")
    var prevHead: String

    @Argument(help: "New HEAD")
    var newHead: String

    @Argument(help: "Branch switch flag (1 = branch switch, 0 = file checkout)")
    var flag: String

    func run() throws {
        print("_hook: not yet implemented")
    }
}
