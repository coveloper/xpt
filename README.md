# xpt

![Version](https://img.shields.io/badge/version-0.3.2-blue) ![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey) ![Swift](https://img.shields.io/badge/swift-6.1-orange) ![License](https://img.shields.io/badge/license-MIT-green) ![Tests](https://github.com/coveloper/xpt/actions/workflows/tests.yml/badge.svg)

Save and restore per-branch Xcode breakpoints automatically.

When you switch git branches, Xcode breakpoints stay anchored to line numbers from the wrong version of your code. xpt fixes this by hooking into `git checkout` to save your breakpoints before you leave a branch and restore them when you return.

---

## How it works

Xcode stores breakpoints in a file called `Breakpoints_v2.xcbkptlist` inside your project's `xcuserdata` directory. xpt copies that file in and out of `~/.xpt/` keyed by repo and branch name. No Xcode plugin, no LLDB scripting — just file copies triggered by a git hook.

The breakpoint file location depends on your Xcode version:

| Xcode version | Breakpoint file path |
|---|---|
| Xcode 16+ | `MyApp.xcodeproj/xcuserdata/<user>.xcuserdatad/xcdebugger/Breakpoints_v2.xcbkptlist` |
| Xcode 15 and earlier | `MyApp.xcodeproj/xcuserdata/<user>.xcuserdatad/Breakpoints_v2.xcbkptlist` |

xpt detects which path is in use automatically — it checks for the `xcdebugger/` path first and falls back to the legacy path. All of `xcuserdata/` is gitignored by `xpt setup`, so neither path ever appears in `git status`.

> [!NOTE]
> Because Xcode loads breakpoints at project-open time and does not watch the file for external changes, xpt uses AppleScript to close and reopen your project after each restore. This makes the new breakpoints appear immediately without any manual steps.

---

## Requirements

- macOS 13 or later
- Xcode with Command Line Tools
- Git

---

## Installation

### Build from source

```sh
git clone https://github.com/coveloper/xpt.git
cd xpt
swift build -c release
cp .build/release/xpt /usr/local/bin/xpt
```

> [!IMPORTANT]
> `xcode-select` must point at your Xcode installation, not the standalone Command Line Tools. If `xcode-select -p` returns `/Library/Developer/CommandLineTools`, run `sudo xcode-select --switch /Applications/Xcode.app` first.

Verify it worked:

```sh
xpt --version
# 0.3.2
```

---

## Quick start

There are two parts to getting xpt running: a one-time global step, and a per-repo setup step.

### Step 1 — Tell xpt which Xcode project to use (per repo)

Run this from the root of your git repo (the same directory that contains your `.xcworkspace` or `.xcodeproj`):

```sh
cd ~/Developer/MyApp
xpt config --set project=MyApp.xcworkspace
```

If your repo contains exactly one `.xcworkspace` or `.xcodeproj` at the root, you can skip this step — xpt will find it automatically.

### Step 2 — Install the git hook

```sh
xpt setup
```

That's it. From this point on, every `git checkout` automatically saves your current branch's breakpoints and restores the new branch's breakpoints.

---

## First use walkthrough

This section walks through a complete example so you can verify everything is working before you rely on it.

### 1. Open your project in Xcode and set some breakpoints

Set a few breakpoints in your code on your current branch (`main` or whatever you're on). Make them distinctive — for example, put one on a specific line in your `AppDelegate` or main view.

### 2. Switch to another branch

```sh
git checkout feature/my-feature
```

xpt runs automatically at this point — it saves your `main` breakpoints, restores any saved breakpoints for `feature/my-feature`, and reloads the Xcode project so the change takes effect immediately. Xcode will close and reopen your project; this is normal.

If `feature/my-feature` has no saved breakpoints yet, xpt clears the breakpoint file (the default behavior) or leaves it alone, depending on your `onEmptyBranch` setting.

### 3. Set breakpoints for the new branch

Your breakpoints from `main` should be gone. Add some new breakpoints that make sense for this feature branch.

### 4. Switch back to main

```sh
git checkout main
```

xpt automatically saves `feature/my-feature`'s breakpoints, restores `main`'s breakpoints, and reloads Xcode. Your original breakpoints should be back exactly where you left them.

### 5. Confirm what's stored

```sh
xpt list
# Saved breakpoints for MyApp (origin: github.com/you/MyApp):
#
#   main                      (2 minutes ago)
#   feature/my-feature        (just now)
```

---

## Command reference

### `xpt setup`

Installs a `post-checkout` git hook in the current repo and updates `.gitignore` with targeted entries for `Breakpoints_v2.xcbkptlist` and `.xpt`.

```sh
xpt setup
```

xpt adds `**/xcuserdata/` to `.gitignore`, which covers breakpoints and all other per-user Xcode data (workspace state, interface layout, etc.). If a broader xcuserdata entry is already present, xpt skips adding a duplicate. Re-running `xpt setup` is safe — it won't add duplicate entries.

If a `post-checkout` hook already exists (from Lefthook, Husky, etc.), xpt will not overwrite it. Instead, it prints the line you need to add manually:

```
xpt setup: A post-checkout hook already exists at .git/hooks/post-checkout.
Add the following line to your existing hook to enable xpt:

    xpt _hook post-checkout "$1" "$2" "$3"
```

---

### `xpt save`

Saves the current breakpoint file as a snapshot for the current branch.

```sh
xpt save
```

Save as a specific branch name:

```sh
xpt save --branch feature/my-feature
```

---

### `xpt restore`

Restores the saved breakpoint snapshot for the current branch.

```sh
xpt restore
```

Restore from a specific branch's snapshot:

```sh
xpt restore --branch main
```

If no snapshot exists for the branch, xpt applies your `onEmptyBranch` policy (see Configuration below).

If Xcode is open, xpt automatically closes and reopens your project so the restored breakpoints take effect immediately. Any active debug session will be terminated — this is expected when switching branches.

---

### `xpt list`

Shows all saved breakpoint snapshots for the current repo.

```sh
xpt list
# Saved breakpoints for MyApp (origin: github.com/you/MyApp):
#
#   main                      (3 days ago)
#   feature/login             (2 hours ago)
#   bugfix/crash-on-launch    (yesterday)
```

---

### `xpt delete`

Removes the saved snapshot for a branch.

```sh
xpt delete feature/old-branch
```

---

### `xpt config`

Displays or sets per-repo configuration.

Show current config:

```sh
xpt config
# Config at /path/to/repo/.xpt:
#
# {
#   "onEmptyBranch" : "clear",
#   "project" : "MyApp.xcworkspace"
# }
```

Set a value:

```sh
xpt config --set project=MyApp.xcworkspace
xpt config --set onEmptyBranch=preserve
```

---

## Configuration

The `.xpt` file at your repo root controls per-repo behaviour. It is created by `xpt config --set` and contains machine-specific settings. `xpt setup` adds it to `.gitignore` automatically.

| Key | Values | Default | Description |
|---|---|---|---|
| `project` | filename | auto-detect | The `.xcworkspace` or `.xcodeproj` to use. Required if your repo root contains more than one. |
| `onEmptyBranch` | `clear` / `preserve` | `clear` | What to do when switching to a branch with no saved breakpoints. `clear` writes an empty breakpoint file. `preserve` leaves the previous branch's breakpoints in place. |

### Choosing between `clear` and `preserve`

**`clear` (default)** — Recommended for most workflows. When you switch to a fresh branch, you start with a clean slate. This prevents stale breakpoints from a different branch cluttering your new context.

**`preserve`** — Useful if you want breakpoints to carry forward when starting work on a new branch from an existing one. For example, if you branch off `main` and want to keep debugging in the same place you were.

---

## Storage

xpt stores snapshots in `~/.xpt/`, organized by repo and branch:

```
~/.xpt/
  <repo-identifier>/           # SHA-256 of the git remote URL (or repo path if no remote)
    main.xcbkptlist
    feature%2Flogin.xcbkptlist  # '/' in branch names is percent-encoded
    bugfix%2Fcrash.xcbkptlist
```

Snapshots are plain XML files — the same format Xcode uses. You can inspect them with any text editor.

To remove all stored snapshots for a repo, delete its directory from `~/.xpt/`. To wipe everything:

```sh
rm -rf ~/.xpt/
```

---

## Working with existing git hooks

If you already have a `post-checkout` hook (common with Lefthook, Husky, or custom scripts), `xpt setup` will detect it and print the snippet to add manually rather than overwriting your hook:

```sh
xpt setup
# xpt setup: A post-checkout hook already exists at .git/hooks/post-checkout.
# Add the following line to your existing hook to enable xpt:
#
#     xpt _hook post-checkout "$1" "$2" "$3"
```

Open `.git/hooks/post-checkout` in your editor and add that line.

---

## Using from the Xcode debugger console

You can call xpt directly from the LLDB console using the `shell` command — no need to leave the debugger:

```
(lldb) shell xpt save
(lldb) shell xpt list
```

This is handy for capturing a precise breakpoint state before a risky rebase or experiment.

---

## Troubleshooting

**"No .xcworkspace or .xcodeproj found in the repo root"**

Your repo root has either no Xcode project, or more than one. Tell xpt which to use:

```sh
xpt config --set project=MyApp.xcworkspace
```

**"No breakpoint file found"**

Xcode hasn't created the breakpoint file yet. Open Xcode, set at least one breakpoint, then run `xpt save`.

**Breakpoints didn't restore after switching branches**

1. Confirm the hook is installed: `cat .git/hooks/post-checkout`
2. Confirm `xpt` is in your PATH: `which xpt`
3. Try a manual restore: `xpt restore` — this also reloads Xcode automatically if it's open
4. If Xcode didn't reopen automatically, close and reopen it manually

**Branch switched but nothing happened**

The `post-checkout` hook only fires on branch switches (flag `$3 == 1`), not on individual file checkouts. Confirm you're doing a full `git checkout <branch>`, not `git checkout -- <file>`.

**"A post-checkout hook already exists"**

See [Working with existing git hooks](#working-with-existing-git-hooks) above.

---

## Multi-project repos

If your repo contains multiple `.xcworkspace` or `.xcodeproj` files, xpt requires explicit configuration:

```sh
xpt config --set project=MyApp.xcworkspace
```

Without this, xpt exits with an error listing the candidates it found.

---

## Uninstalling

Remove the binary:

```sh
rm /usr/local/bin/xpt
```

Remove the git hook from any repo where you installed it:

```sh
rm .git/hooks/post-checkout
```

Remove all stored snapshots:

```sh
rm -rf ~/.xpt/
```

---

## License

MIT. See [LICENSE](LICENSE).
