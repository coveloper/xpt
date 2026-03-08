import ArgumentParser

@main
struct XMark: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "xmark",
        abstract: "Save and restore per-branch Xcode breakpoints.",
        version: "0.1.0",
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
