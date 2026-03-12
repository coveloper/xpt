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

        // Escape the path for safe embedding in an AppleScript string literal.
        // AppleScript has no backslash escape for double quotes inside strings;
        // the safe approach is to split on `"` and rejoin using the `quote` constant.
        // e.g. /path/with"quote → "/path/with" & quote & "quote"
        let escapedPath = escapeForAppleScript(projectURL.path)

        // Close the project document and reopen it so Xcode re-reads the breakpoint file.
        // "saving yes" ensures unsaved source edits are written before closing.
        let script = """
        tell application "Xcode"
            try
                set proj to first workspace document whose path is \(escapedPath)
                close proj saving yes
            on error
                -- project may not be open; just fall through
            end try
        end tell
        delay 0.5
        tell application "Xcode"
            open \(escapedPath)
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

    // MARK: - AppleScript escaping

    /// Wraps a string in an AppleScript string expression, safely handling embedded
    /// double-quote characters by using AppleScript's `quote` constant.
    private static func escapeForAppleScript(_ string: String) -> String {
        let parts = string.components(separatedBy: "\"")
        guard parts.count > 1 else { return "\"\(string)\"" }
        return "\"" + parts.joined(separator: "\" & quote & \"") + "\""
    }
}
