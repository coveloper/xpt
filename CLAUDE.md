# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**xpt** — MIT licensed, hosted at [coveloper/xpt](https://github.com/coveloper/xpt).

A Swift CLI tool that saves and restores per-branch Xcode breakpoints via git hooks.

## Building

`xcode-select` must point to Xcode (not the standalone CLT) due to a PackageDescription dylib issue with the macOS 26 CLT. Use:

```sh
DEVELOPER_DIR=/Applications/Xcode_26.3.app/Contents/Developer swift build
DEVELOPER_DIR=/Applications/Xcode_26.3.app/Contents/Developer swift run xpt --help
```

Or switch xcode-select permanently (requires sudo):
```sh
sudo xcode-select -s /Applications/Xcode_26.3.app/Contents/Developer
```

## Structure

```
Sources/xpt/
  Xpt.swift                # @main entry point, registers all subcommands
  Commands/
    Setup.swift            # xpt setup
    Save.swift             # xpt save
    Restore.swift          # xpt restore
    List.swift             # xpt list
    Delete.swift           # xpt delete
    Config.swift           # xpt config
    Hook.swift             # xpt _hook (internal, called by git hook)
```

## Key Design Notes

- Breakpoint file: `<project>/xcuserdata/<USER>.xcuserdatad/Breakpoints_v2.xcbkptlist`
- Storage: `~/.xpt/<repo-sha>/`  (SHA-256 of remote URL or repo root path)
- Per-repo config: `.xpt` JSON at repo root (gitignored)
- Git hook: `post-checkout`, installed by `xpt setup`

## Git Commits

Only commit to THIS repository (`/Users/jonbauer/Developer/Projects/Xpt/Dev/Source/xpt/`).
