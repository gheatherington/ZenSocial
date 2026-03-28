---
phase: quick
plan: 260328-cli
type: execute
wave: 1
depends_on: []
files_modified:
  - VERSION
  - .git/hooks/prepare-commit-msg
  - ZenSocial.xcodeproj/project.pbxproj
autonomous: true
requirements: []

must_haves:
  truths:
    - "Every git commit increments the build number automatically"
    - "Commit messages include the build number (e.g., [build 42])"
    - "CURRENT_PROJECT_VERSION in project.pbxproj stays in sync"
  artifacts:
    - path: "VERSION"
      provides: "Single source of truth for the current build number (integer)"
    - path: ".git/hooks/prepare-commit-msg"
      provides: "Git hook that increments VERSION, updates pbxproj, and prepends build number to commit message"
  key_links:
    - from: ".git/hooks/prepare-commit-msg"
      to: "ZenSocial.xcodeproj/project.pbxproj"
      via: "sed replacement of CURRENT_PROJECT_VERSION"
      pattern: "CURRENT_PROJECT_VERSION"
    - from: "VERSION"
      to: ".git/hooks/prepare-commit-msg"
      via: "read/write integer build number"
      pattern: "cat VERSION"
---

<objective>
Add automatic build number tracking to the project. On every git commit, a hook reads the current integer build number from a VERSION file, increments it, writes it back, syncs CURRENT_PROJECT_VERSION in project.pbxproj, stages those two files, and prepends "[build N]" to the commit message.

Purpose: Tracks change cadence without manual bookkeeping and ties every commit to a specific build number for debugging.
Output: VERSION file + prepare-commit-msg hook that runs automatically on every commit.
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
</context>

<tasks>

<task type="auto">
  <name>Task 1: Create VERSION file and prepare-commit-msg hook</name>
  <files>VERSION, .git/hooks/prepare-commit-msg</files>
  <action>
    1. Create `VERSION` at repo root containing the integer `1` (current build number, matching the existing CURRENT_PROJECT_VERSION = 1 in project.pbxproj).

    2. Create `.git/hooks/prepare-commit-msg` as an executable shell script with the following logic:

    ```bash
    #!/usr/bin/env bash
    # prepare-commit-msg: auto-increment build number on every non-merge commit

    COMMIT_MSG_FILE="$1"
    COMMIT_SOURCE="$2"   # "merge", "squash", "commit", etc.

    # Skip merge commits, squash commits, and fixup commits
    if [ "$COMMIT_SOURCE" = "merge" ] || [ "$COMMIT_SOURCE" = "squash" ]; then
      exit 0
    fi

    VERSION_FILE="$(git rev-parse --show-toplevel)/VERSION"
    PBXPROJ="$(git rev-parse --show-toplevel)/ZenSocial.xcodeproj/project.pbxproj"

    # Read and increment
    CURRENT=$(cat "$VERSION_FILE" 2>/dev/null || echo "0")
    NEXT=$((CURRENT + 1))

    # Write new build number
    echo "$NEXT" > "$VERSION_FILE"

    # Update CURRENT_PROJECT_VERSION in pbxproj (both Debug and Release entries)
    sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9]*/CURRENT_PROJECT_VERSION = $NEXT/g" "$PBXPROJ"

    # Stage the two modified files
    git add "$VERSION_FILE" "$PBXPROJ"

    # Prepend build tag to the commit message
    ORIGINAL_MSG=$(cat "$COMMIT_MSG_FILE")
    echo "[build $NEXT] $ORIGINAL_MSG" > "$COMMIT_MSG_FILE"
    ```

    Make the hook executable: `chmod +x .git/hooks/prepare-commit-msg`

    Note: `.git/hooks/` is not tracked by git — this is intentional (hooks are local). If team sharing is ever needed, copy the script to a `scripts/hooks/` directory and document installation. For now, local-only is fine.
  </action>
  <verify>
    <automated>
      # Verify VERSION file exists with integer content
      test -f /Users/gavin/Documents/Projects/ZenSocial/VERSION && cat /Users/gavin/Documents/Projects/ZenSocial/VERSION

      # Verify hook exists and is executable
      test -x /Users/gavin/Documents/Projects/ZenSocial/.git/hooks/prepare-commit-msg && echo "hook is executable"

      # Dry-run syntax check of the hook script
      bash -n /Users/gavin/Documents/Projects/ZenSocial/.git/hooks/prepare-commit-msg && echo "syntax OK"
    </automated>
  </verify>
  <done>VERSION contains integer "1", hook exists at .git/hooks/prepare-commit-msg and is executable, bash syntax check passes.</done>
</task>

<task type="auto">
  <name>Task 2: Commit VERSION file to repo (hook fires on this commit — proves end-to-end)</name>
  <files>VERSION</files>
  <action>
    Stage and commit the VERSION file. This commit will fire the prepare-commit-msg hook, which will:
    - Increment VERSION from 1 to 2
    - Update CURRENT_PROJECT_VERSION in project.pbxproj to 2
    - Stage both files
    - Prepend "[build 2]" to the commit message

    Run:
    ```bash
    git add VERSION
    git commit -m "feat: add version tracking — build number auto-increments on each commit"
    ```

    After the commit, verify:
    - `cat VERSION` outputs `2`
    - `git log --oneline -1` shows `[build 2] feat: add version tracking...`
    - `grep CURRENT_PROJECT_VERSION ZenSocial.xcodeproj/project.pbxproj` shows `= 2` (both entries)

    Do NOT add any Co-Authored-By trailers to the commit message.
  </action>
  <verify>
    <automated>
      # All three checks in sequence
      BUILD=$(cat /Users/gavin/Documents/Projects/ZenSocial/VERSION) && echo "VERSION=$BUILD"
      git -C /Users/gavin/Documents/Projects/ZenSocial log --oneline -1
      grep "CURRENT_PROJECT_VERSION" /Users/gavin/Documents/Projects/ZenSocial/ZenSocial.xcodeproj/project.pbxproj
    </automated>
  </verify>
  <done>VERSION=2, latest commit message starts with "[build 2]", both CURRENT_PROJECT_VERSION entries in project.pbxproj equal 2.</done>
</task>

<task type="auto">
  <name>Task 3: Update STATE.md quick tasks log</name>
  <files>.planning/STATE.md</files>
  <action>
    Append a row to the Quick Tasks Completed table in STATE.md:

    | 260328-cli | Add version tracking — build number auto-increments on each commit | 2026-03-28 | {commit hash} | [260328-cli-add-version-tracking-to-project-incremen](./quick/260328-cli-add-version-tracking-to-project-incremen/) |

    Replace {commit hash} with the actual short SHA from Task 2's commit.
  </action>
  <verify>
    <automated>grep "260328-cli" /Users/gavin/Documents/Projects/ZenSocial/.planning/STATE.md</automated>
  </verify>
  <done>STATE.md quick tasks table contains the 260328-cli row with real commit hash.</done>
</task>

</tasks>

<verification>
After all tasks complete:
- `cat VERSION` → integer >= 2
- `git log --oneline -1` → commit message starts with "[build N]"
- `grep CURRENT_PROJECT_VERSION ZenSocial.xcodeproj/project.pbxproj` → both entries match VERSION
- Make one additional test commit (e.g., amend STATE.md) and confirm the build number increments again
</verification>

<success_criteria>
Every subsequent `git commit` in this repo automatically:
1. Increments the integer in VERSION
2. Syncs CURRENT_PROJECT_VERSION in project.pbxproj
3. Prepends "[build N]" to the commit message
No manual steps required after this plan executes.
</success_criteria>

<output>
After completion, create `.planning/quick/260328-cli-add-version-tracking-to-project-incremen/260328-cli-SUMMARY.md`
</output>
