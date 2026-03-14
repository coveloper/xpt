import ArgumentParser

@main
struct Xpt: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "xpt",
        abstract: "Save and restore per-branch Xcode breakpoints.",
        version: "0.3.2",
        subcommands: [
            Setup.self,
            Save.self,
            Restore.self,
            List.self,
            Delete.self,
            Config.self,
            Hook.self,
        ]
    )
}
