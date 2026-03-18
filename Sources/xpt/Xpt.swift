import ArgumentParser
import xptCore

@main
struct Xpt: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "xpt",
        abstract: "Save and restore per-branch Xcode breakpoints.",
        version: "0.4.0",
        subcommands: [
            Setup.self,
            Save.self,
            Restore.self,
            List.self,
            Delete.self,
            Rename.self,
            Config.self,
            Hook.self,
        ]
    )
}
