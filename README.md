# xmark

Save and restore per-branch Xcode breakpoints automatically.

When you switch git branches, Xcode breakpoints stay anchored to line numbers from the wrong version of your code. xmark fixes this by hooking into `git checkout` to save your breakpoints before you leave a branch and restore them when you return.

---

## How it works

Xcode stores breakpoints in a file called `Breakpoints_v2.xcbkptlist` inside your project's `xcuserdata` directory. xmark copies that file in and out of `~/.xmark/` keyed by repo and branch name. No Xcode plugin, no LLDB scripting — just file copies triggered by a git hook.

---

## Requirements

- macOS 13 or later
- Xcode with Command Line Tools
- Git

---

## Installation

### Build from source

```sh
git clone https://github.com/coveloper/xmark.git
cd xmark
swift build -c release
cp .build/release/xmark /usr/local/bin/xmark
```

Verify it worked:

```sh
xmark --version
# 0.1.0
```

> **Note for Xcode 26 users:** If the build fails with a PackageDescription linker error, set `DEVELOPER_DIR` explicitly:
> ```sh
> DEVELOPER_DIR=/Applications/Xcode_26.3.app/Contents/Developer swift build -c release
> ```

---

## Quick start

There are two parts to getting xmark running: a one-time global step, and a per-repo setup step.

### Step 1 — Tell xmark which Xcode project to use (per repo)

Run this from the root of your git repo (the same directory that contains your `.xcworkspace` or `.xcodeproj`):

```sh
cd ~/Developer/MyApp
xmark config --set project=MyApp.xcworkspace
```

If your repo contains exactly one `.xcworkspace` or `.xcodeproj` at the root, you can skip this step — xmark will find it automatically.

Add `.xmark` to your `.gitignore` so the config file stays local to your machine:

```sh
echo ".xmark" >> .gitignore
```

### Step 2 — Install the git hook

```sh
xmark setup
```

That's it. From this point on, every `git checkout` automatically saves your current branch's breakpoints and restores the new branch's breakpoints.

---

## First use walkthrough

This section walks through a complete example so you can verify everything is working before you rely on it.

### 1. Open your project in Xcode and set some breakpoints

Set a few breakpoints in your code on your current branch (`main` or whatever you're on). Make them distinctive — for example, put one on a specific line in your `AppDelegate` or main view.

### 2. Save your current branch's breakpoints manually

```sh
xmark save
# xmark: Breakpoints saved for branch 'main'.
```

### 3. Switch to another branch

```sh
git checkout feature/my-feature
```

If the hook is installed, xmark runs automatically at this point. You'll see no output during the switch — xmark is silent on success. If `feature/my-feature` has no saved breakpoints yet, xmark clears the breakpoint file (the default behavior) or leaves it alone, depending on your `onEmptyBranch` setting.

### 4. Open Xcode

Your breakpoints from `main` should be gone. Add some new breakpoints that make sense for this feature branch.

### 5. Switch back to main

```sh
git checkout main
```

xmark automatically saves `feature/my-feature`'s breakpoints and restores `main`'s breakpoints. Open Xcode — your original breakpoints should be back exactly where you left them.

### 6. Confirm what's stored

```sh
xmark list
# Saved breakpoints for MyApp (origin: github.com/you/MyApp):
#
#   main                      (2 minutes ago)
#   feature/my-feature        (just now)
```

---

## Command reference

### `xmark setup`

Installs a `post-checkout` git hook in the current repo.

```sh
xmark setup
```

If a `post-checkout` hook already exists (from Lefthook, Husky, etc.), xmark will not overwrite it. Instead, it prints the line you need to add manually:

```
xmark setup: A post-checkout hook already exists at .git/hooks/post-checkout.
Add the following line to your existing hook to enable xmark:

    xmark _hook post-checkout "$1" "$2" "$3"
```

---

### `xmark save`

Saves the current breakpoint file as a snapshot for the current branch.

```sh
xmark save
```

Save as a specific branch name:

```sh
xmark save --branch feature/my-feature
```

---

### `xmark restore`

Restores the saved breakpoint snapshot for the current branch.

```sh
xmark restore
```

Restore from a specific branch's snapshot:

```sh
xmark restore --branch main
```

If no snapshot exists for the branch, xmark applies your `onEmptyBranch` policy (see Configuration below).

> **Xcode open?** xmark will warn you if Xcode is running when you restore. Xcode may not pick up the change until it's restarted, though in practice it often does reload the file automatically.

---

### `xmark list`

Shows all saved breakpoint snapshots for the current repo.

```sh
xmark list
# Saved breakpoints for MyApp (origin: github.com/you/MyApp):
#
#   main                      (3 days ago)
#   feature/login             (2 hours ago)
#   bugfix/crash-on-launch    (yesterday)
```

---

### `xmark delete`

Removes the saved snapshot for a branch.

```sh
xmark delete feature/old-branch
```

---

### `xmark config`

Displays or sets per-repo configuration.

Show current config:

```sh
xmark config
# Config at /path/to/repo/.xmark:
#
# {
#   "onEmptyBranch" : "clear",
#   "project" : "MyApp.xcworkspace"
# }
```

Set a value:

```sh
xmark config --set project=MyApp.xcworkspace
xmark config --set onEmptyBranch=preserve
```

---

## Configuration

The `.xmark` file at your repo root controls per-repo behaviour. It is created by `xmark config --set` and should be added to `.gitignore` — it contains machine-specific settings.

| Key | Values | Default | Description |
|---|---|---|---|
| `project` | filename | auto-detect | The `.xcworkspace` or `.xcodeproj` to use. Required if your repo root contains more than one. |
| `onEmptyBranch` | `clear` / `preserve` | `clear` | What to do when switching to a branch with no saved breakpoints. `clear` writes an empty breakpoint file. `preserve` leaves the previous branch's breakpoints in place. |

### Choosing between `clear` and `preserve`

**`clear` (default)** — Recommended for most workflows. When you switch to a fresh branch, you start with a clean slate. This prevents stale breakpoints from a different branch cluttering your new context.

**`preserve`** — Useful if you want breakpoints to carry forward when starting work on a new branch from an existing one. For example, if you branch off `main` and want to keep debugging in the same place you were.

---

## Storage

xmark stores snapshots in `~/.xmark/`, organized by repo and branch:

```
~/.xmark/
  <repo-identifier>/           # SHA-256 of the git remote URL (or repo path if no remote)
    main.xcbkptlist
    feature__login.xcbkptlist  # '/' in branch names is stored as '__'
    bugfix__crash.xcbkptlist
```

Snapshots are plain XML plist files — the same format Xcode uses. You can inspect them with any text editor.

To remove all stored snapshots for a repo, delete its directory from `~/.xmark/`. To wipe everything:

```sh
rm -rf ~/.xmark/
```

---

## Working with existing git hooks

If you already have a `post-checkout` hook (common with Lefthook, Husky, or custom scripts), `xmark setup` will detect it and print the snippet to add manually rather than overwriting your hook:

```sh
xmark setup
# xmark setup: A post-checkout hook already exists at .git/hooks/post-checkout.
# Add the following line to your existing hook to enable xmark:
#
#     xmark _hook post-checkout "$1" "$2" "$3"
```

Open `.git/hooks/post-checkout` in your editor and add that line.

---

## Using from the Xcode debugger console

You can call xmark directly from the LLDB console using the `!` shell escape prefix — no need to leave the debugger:

```
(lldb) !xmark save
(lldb) !xmark list
```

This is handy for capturing a precise breakpoint state before a risky rebase or experiment.

---

## Troubleshooting

**"No .xcworkspace or .xcodeproj found in the repo root"**

Your repo root has either no Xcode project, or more than one. Tell xmark which to use:

```sh
xmark config --set project=MyApp.xcworkspace
```

**"No breakpoint file found"**

Xcode hasn't created the breakpoint file yet. Open Xcode, set at least one breakpoint, then run `xmark save`.

**Breakpoints didn't restore after switching branches**

1. Confirm the hook is installed: `cat .git/hooks/post-checkout`
2. Confirm `xmark` is in your PATH: `which xmark`
3. Try a manual restore to confirm the snapshot exists: `xmark restore`
4. If Xcode is open, close and reopen it — Xcode may not pick up file changes while running.

**Branch switched but nothing happened**

The `post-checkout` hook only fires on branch switches (flag `$3 == 1`), not on individual file checkouts. Confirm you're doing a full `git checkout <branch>`, not `git checkout -- <file>`.

**"A post-checkout hook already exists"**

See [Working with existing git hooks](#working-with-existing-git-hooks) above.

---

## Multi-project repos

If your repo contains multiple `.xcworkspace` or `.xcodeproj` files, xmark requires explicit configuration:

```sh
xmark config --set project=MyApp.xcworkspace
```

Without this, xmark exits with an error listing the candidates it found.

---

## Uninstalling

Remove the binary:

```sh
rm /usr/local/bin/xmark
```

Remove the git hook from any repo where you installed it:

```sh
rm .git/hooks/post-checkout
```

Remove all stored snapshots:

```sh
rm -rf ~/.xmark/
```

---

## License

MIT. See [LICENSE](LICENSE).
