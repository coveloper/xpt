import Foundation

enum XcodeUtilities {
    // MARK: - Running check

    static var isRunning: Bool {
        let result = try? GitUtilities.run("pgrep", "-x", "Xcode")
        return result != nil && !result!.isEmpty
    }

    // MARK: - Project reload

    /// Closes and reopens the current project document in Xcode so it picks up
    /// the restored breakpoint file. Less disruptive than quitting Xcode entirely.
    ///
    /// Returns true if the reload was attempted, false if Xcode wasn't running.
    @discardableResult
    static func reloadProject(projectURL: URL) -> Bool {
        guard isRunning else { return false }

        let projectPath = projectURL.path

        // Close the project document and reopen it so Xcode re-reads the breakpoint file.
        // "saving yes" ensures unsaved source edits are written before closing.
        let script = """
        tell application "Xcode"
            try
                set proj to first workspace document whose path is "\(projectPath)"
                close proj saving yes
            on error
                -- project may not be open; just fall through
            end try
        end tell
        delay 0.5
        tell application "Xcode"
            open "\(projectPath)"
            activate
        end tell
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try? process.run()
        process.waitUntilExit()

        return true
    }
}
