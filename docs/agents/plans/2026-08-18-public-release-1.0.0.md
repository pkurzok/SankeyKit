---
date: 2026-08-18T13:18:20.956293+00:00
git_commit: ""
branch: main
topic: "Public release: sanitize, verify and tag SankeyKit 1.0.0"
tags: [plan, release, git-history, ci, readme, documentation]
status: complete
---

# PLAN: Public release — sanitize, verify and tag SankeyKit 1.0.0

`github.com/pkurzok/SankeyKit` is private, untagged, and carries three things that should not
survive the transition to public: an employer email address on 10 of its 14 commits, an Apple
Team ID and an absolute home path inside `docs/`, and a handful of README claims the source code
no longer supports.

An audit found **no blocking problem** — no credentials, tokens, private keys or `.env` files
tracked or in history; the seven JPEGs in `Documentation.docc/Resources/` carry no EXIF or author
metadata; history contains no deleted files and its largest blob is 176 KB; `.build/`,
`Package.resolved`, `.DS_Store` and the generated `.xcodeproj` are all correctly ignored. The
package builds, 112 tests pass, `swiftlint --strict` reports 0 violations and the DocC archive
generates.

This plan corrects the published surface, proves the platform claims in CI, rewrites history while
the repo is still private, then makes it public and tags `1.0.0`.

## Placeholders

This plan is itself a tracked file under `docs/agents/plans/`, so it deliberately never spells out
the two values it exists to remove — writing them here would republish them and would make
Phase 3's `--tree-filter` rewrite its own `sed` script. Resolve both once at the start of Phase 1
and export them for every command below:

| Placeholder | Where to read the real value | Shape |
|---|---|---|
| `$TEAM_ID` | `docs/agents/plans/2026-08-18-swiftui-way-audit-fixes.md:276`, in `DEVELOPMENT_TEAM=…` | 10-character Apple Team ID |
| `$HOME_PATH` | `docs/agents/plans/2026-08-17-sankeykit-package.md:55`, the backticked path at the start of the line | `/Users/<user>/<dir>/SankeyKit` |

```sh
export TEAM_ID="$(grep -oE 'DEVELOPMENT_TEAM=[A-Z0-9]+' \
  docs/agents/plans/2026-08-18-swiftui-way-audit-fixes.md | cut -d= -f2)"
export HOME_PATH="$(grep -oE '/Users/[^ `]+/SankeyKit' \
  docs/agents/plans/2026-08-17-sankeykit-package.md | head -1)"
```

Both must be non-empty before proceeding. After Phase 1 the first command returns nothing — that is
the point — so export them **before** editing, and keep them in the shell through Phase 3.

## Out of Scope

Deliberately excluded, and worth revisiting after 1.0.0 ships:

- **Branch protection on `main`.** Unavailable on a private free repo (`gh api … /protection`
  returns 403), and it would become configurable only after Phase 4 — after the last force-push.
  Adding it earlier would block Phase 3.
- **Swift Package Index registration**, which would also host the DocC archive. A separate,
  post-release step; the repo homepage is therefore left unset rather than pointed at a page that
  does not exist yet.
- **GitHub Pages DocC hosting**, considered and dropped: it adds a workflow to build and debug
  before tagging.
- **Issue templates and `SECURITY.md`**, considered and dropped for a drawing library with no
  network or crypto surface.
- **The `de.peterkurzok.*` identifiers** (log subsystem, demo bundle ID). A reverse-DNS name from a
  domain the author owns is standard practice for a Swift package, not a leak.

## Acceptance Criteria

- `git log --format='%ae %ce' --all | tr ' ' '\n' | sort -u` yields only `github@peterkurzok.de`
  and `noreply@github.com`.
- `git log -S "$TEAM_ID" --all` and `git log -S "$HOME_PATH" --all` both produce no output,
  with the two values resolved from the Placeholders table above.
- `git config --local user.email` is `github@peterkurzok.de`, so future commits and the tag are
  unaffected by the work address in `~/.gitconfig`.
- CI compiles the package for every platform listed in `Package.swift`, and that list matches the
  README requirements table exactly.
- No README or DocC claim is contradicted by the source: the unit-test count, the ribbon-math
  credits and the tvOS selection note all match `Tests/`, `RibbonGeometry.swift` and
  `SankeyChart+Accessibility.swift` respectively.
- `swift build`, `swift test`, `swiftlint --strict` and
  `swift package generate-documentation --target SankeyKit` all pass.
- `CHANGELOG.md` and `CONTRIBUTING.md` exist, and the CHANGELOG has a `1.0.0` entry.
- `gh repo view pkurzok/SankeyKit --json visibility` reports `PUBLIC`.
- Tag `1.0.0` and a GitHub Release named `SankeyKit 1.0.0` exist.
- Repo topics are set (`swift`, `swiftui`, `sankey`, `charts`, `data-visualization`,
  `swift-package`).
- A throwaway package depending on `.package(url: "…/SankeyKit.git", from: "1.0.0")` resolves and
  builds against the public repository.

## Technical Key Decisions and Tradeoffs

1. **Rewrite the author/committer email on all 14 commits.** `peter.kurzok@maibornwolff.de`
   (employer) → `github@peterkurzok.de`.
   - Why: a personal MIT-licensed project carrying an employer identity is both a privacy leak and
     an IP-ownership ambiguity. The repo has 0 forks, 0 stars, 0 open issues and no external
     clones, so this is free today and impossible once published.
   - Impact: `git filter-branch --env-filter`, force-push, every commit SHA changes.

2. **Scrub the Team ID and home path from file contents in the same pass**, via `--tree-filter`.
   - Why: the force-push is happening regardless. A redaction that leaves the value readable in
     `git log -p` is cosmetic, not a redaction.
   - Impact: one `sed` over `docs/**/*.md`, guarded because `docs/` does not exist in the earliest
     commits.

3. **Use `git filter-branch`, not `git-filter-repo`.**
   - Why: `git-filter-repo` is not installed (verified: not on `PATH`, not in pip, not in brew);
     14 commits do not justify adding a tool. `filter-branch` is built in.
   - Impact: a deprecation warning, silenced with `FILTER_BRANCH_SQUELCH_WARNING=1`, and a
     `refs/original/` backup ref that must be cleaned up afterwards.

4. **Delete the two stale local branches before rewriting.** `swiftui-way-audit-fixes` and
   `fix/ios27-toggle-animation` both track remotes that are `gone` (their PRs #3 and #4 were merged
   into `main`).
   - Why: `-- --all` would otherwise rewrite branches that will never be pushed, doubling the work
     and leaving confusing rewritten refs behind.
   - Impact: two `git branch -D` calls; no content is lost, it is all in `main`.

5. **Keep `docs/`, sanitized rather than deleted.**
   - Why: the plans document *why* the code looks as it does — the iOS 27 `Toggle` workaround in
     `FinanceDemoView` is incomprehensible without them — and `CLAUDE.md` documents
     `docs/agents/plans/` as the convention.

6. **Leave the historical "private repo" statements in `2026-08-17-sankeykit-package.md` alone.**
   This is a refinement of what was discussed during planning.
   - Why: that document is `status: complete` and dated. Lines like *"a private GitHub repo …
     ready to go public later"* and *"`gh repo view` reports `PRIVATE`"* were **true on
     2026-08-17**. Editing a completed record to match today's state falsifies it, and they leak
     nothing. Only genuinely sensitive values get redacted.
   - Impact: smaller diff; the record stays honest.

7. **Leave `~/Library/Developer/Toolchains` in `2026-08-18-ribbon-node-overlap.md:206`.**
   - Why: it is the standard macOS toolchain location and contains no username. It was flagged
     during the audit for completeness, not because it discloses anything.

8. **Re-attribute the Credits to d3-shape / d3-sankey**, keeping the Medium article as original
   inspiration.
   - Why: the README credits *"control points offset in both axes"*, but
     `RibbonGeometry.controlPoints` (`RibbonGeometry.swift:44`) offsets only in x — it is
     `d3-shape`'s `bumpX`, adopted deliberately in the curved-ribbons work. The credited formula
     is gone from the code.
   - Impact: a rewritten Credits section; no code change.

9. **Add a five-platform CI build matrix; fix small breaks, otherwise drop the platform.**
   - Why: the README promises iOS/macOS/tvOS/watchOS/visionOS, but CI only ran `swift build` +
     `swift test` on macOS. Locally iOS, macOS and visionOS build; tvOS and watchOS could not be
     checked because their SDKs are not installed on this Mac (`tvOS 26.5 is not installed`) —
     they have therefore **never been compiled anywhere**.
   - Impact: 1.0.0's platform list becomes verified rather than asserted. If a platform needs
     structural change to compile, it comes out of `Package.swift` and the README and becomes a
     1.1 candidate.

10. **Sequence: PR → merge → rewrite → public → tag.**
    - Why: the content work must be validated by the new matrix *before* it becomes history, and
      rewriting while private guarantees nobody holds the old SHAs.

## Current State

```
github.com/pkurzok/SankeyKit        PRIVATE · MIT · 0 tags · 0 forks · 0 stars · 0 issues

git history (14 commits)
  ae86665  github@peterkurzok.de        ← PR #4
  97b2b1f  github@peterkurzok.de        ← PR #3
  9b8c414  github@peterkurzok.de        ← PR #2
  2056762  github@peterkurzok.de        ← PR #1
  7d5fa06  peter.kurzok@maibornwolff.de ┐
  a3eebf8  peter.kurzok@maibornwolff.de │
  …        …                            ├ 10 commits, author AND committer
  e531687  peter.kurzok@maibornwolff.de ┘
  git config user.email → peter.kurzok@maibornwolff.de   (from ~/.gitconfig, no local override)

stale local branches (remote gone, content merged via #3/#4)
  swiftui-way-audit-fixes      921ddb0
  fix/ios27-toggle-animation   68d50c1

sensitive strings in tracked files AND in history
  docs/agents/plans/2026-08-18-swiftui-way-audit-fixes.md:276   DEVELOPMENT_TEAM=$TEAM_ID
  docs/agents/plans/2026-08-17-sankeykit-package.md:55          $HOME_PATH/

stale frontmatter (SHAs invalidated by the rewrite)
  docs/agents/plans/2026-08-18-ios27-toggle-animation-fix.md:3  git_commit: 97b2b1f5…
  docs/agents/plans/2026-08-18-swiftui-way-audit-fixes.md:3     git_commit: 9b8c414c…

claims contradicted by the source
  README.md:52    "covered by 100 unit tests"      → swift test reports 112 in 13 suites
  README.md:65    "on tvOS the diagram is          → since 97b2b1f, sankeyNodeAccessibility attaches
                   read-only"                         .accessibilityAction + .isButton, so
  SankeyKit.md:49 (same sentence)                     accessibility activation *does* select
  README.md:239   "control points offset in        → RibbonGeometry.swift:44 offsets x only;
                   both axes" → jc_builds article      that is d3-shape's bumpX

CI (.github/workflows/ci.yml)
  lint:  swiftlint --strict                        macos-latest
  test:  swift build && swift test                 macos-latest    ← macOS only
                                                                      ↑ tvOS/watchOS/visionOS
                                                                        never compiled

meta files
  README.md  LICENSE  CLAUDE.md          (no CHANGELOG, no CONTRIBUTING)
```

## Desired End State

```
github.com/pkurzok/SankeyKit        PUBLIC · MIT · tag 1.0.0 + Release · topics set

git history (14 commits + 1 content commit, all SHAs new)
  <new>    github@peterkurzok.de        × all
  git log -S "$TEAM_ID"            → (empty)
  git log -S "$HOME_PATH"          → (empty)
  git config --local user.email    → github@peterkurzok.de

CI
  lint:       swiftlint --strict                      macos-latest
  test:       swift build && swift test               macos-latest
  platforms:  xcodebuild -destination generic/platform=$P   matrix, fail-fast: false
              iOS · macOS · tvOS · watchOS · visionOS
                     ↑ every platform in Package.swift, and Package.swift == README table

meta files
  README.md  LICENSE  CLAUDE.md  CHANGELOG.md  CONTRIBUTING.md
```

## Abstractions and Code Reuse

No new source abstractions. This release touches documentation, CI configuration and git metadata;
`Sources/SankeyKit/` changes only if the platform matrix uncovers a compile failure.

- `README.md` — three factual corrections
  - line 52 — test count `100` → the number `swift test` actually reports
  - line 65 — the tvOS selection sentence, reconciled with `SankeyChart+Accessibility.swift`
  - lines 237–242 — Credits section rewritten around `d3-shape` `bumpX` / `d3-sankey`
- `Sources/SankeyKit/Documentation.docc/`
  - `SankeyKit.md` — line 49, same tvOS sentence as `README.md:65`
- `docs/agents/plans/` — sanitized in place
  - `2026-08-18-swiftui-way-audit-fixes.md` — line 276 Team ID redacted, line 3 `git_commit` emptied
  - `2026-08-17-sankeykit-package.md` — line 55 absolute path → relative phrasing
  - `2026-08-18-ios27-toggle-animation-fix.md` — line 3 `git_commit` emptied
  - `2026-08-18-public-release-1.0.0.md` — this file; its own `git_commit` emptied in Phase 1
- `.github/workflows/ci.yml` — new `platforms` job
  - `strategy.matrix.platform` — the five destinations, `fail-fast: false`
- `CHANGELOG.md` *(new)* — Keep a Changelog format, `1.0.0` entry
- `CONTRIBUTING.md` *(new)* — branch-then-PR, green CI, `swiftlint --strict`; a public restatement
  of the conventions already in `CLAUDE.md`
- `Package.swift` — touched **only** if a platform must be dropped

## Logging & Observability

No changes. `SankeyGraph.swift:190` keeps logging to the `de.peterkurzok.SankeyKit` subsystem —
that identifier is a reverse-DNS name derived from a domain the author owns, which is standard
practice for a Swift package and is deliberately left as is.

## Implementation

### Phase 1: Public-surface correctness

Dependencies: None.

Sanitize `docs/`, correct every README and DocC claim the source contradicts, and add the two meta
files. Lands on a branch; the PR opens here and is merged at the end of Phase 2.

**Tasks**:
- [x] Create the branch: `git switch -c release/public-1.0.0`
- [x] `docs/agents/plans/2026-08-18-swiftui-way-audit-fixes.md:276` — replace
      `DEVELOPMENT_TEAM=$TEAM_ID` with `DEVELOPMENT_TEAM=<your team ID>`, keeping the
      surrounding sentence intact
- [x] `docs/agents/plans/2026-08-17-sankeykit-package.md:55` — replace
      `` `$HOME_PATH/` is empty `` with `The package root is empty`
- [x] Empty the `git_commit:` frontmatter field in **every** file under `docs/agents/plans/` that
      still carries one — `2026-08-18-ios27-toggle-animation-fix.md:3`,
      `2026-08-18-swiftui-way-audit-fixes.md:3` and **this plan's own line 3** (`ae86665…`, which
      Phase 3 invalidates just like the rest) — and replace the two SHAs quoted in the prose of
      `2026-08-18-ios27-toggle-animation-fix.md` with descriptive references
      (`the toggle-accessibility commit and its parent`)
- [x] Do **not** edit the "private repo" statements in `2026-08-17-sankeykit-package.md`
      (lines 12, 324, 334, 341) — see decision 6
- [x] `README.md:52` — replace `100` with the count `swift test` reports; run the test suite first
      and use its number
- [x] `README.md:65` and `Sources/SankeyKit/Documentation.docc/SankeyKit.md:49` — reword the tvOS
      sentence so it matches `SankeyChart+Accessibility.swift`. Suggested wording:

      ```
      Selection is driven by taps and by accessibility activation. tvOS has no pointer, so
      there a chart is selectable through VoiceOver but not by remote alone.
      ```

- [x] `README.md:237-242` — rewrite Credits:

      ```markdown
      ## Credits

      Column assignment and ribbon geometry both follow
      [d3-sankey](https://github.com/d3/d3-sankey): columns via longest-path layering, and each
      ribbon a cubic Bézier whose control points sit on the horizontal midpoint — `d3-shape`'s
      `bumpX` curve.

      The first version of this package took its approach from
      [Easily add a clean SwiftUI Sankey diagram to your app](https://medium.com/@jc_builds/easily-add-a-clean-swiftui-sankey-diagram-to-your-app-c4972b55d0c1)
      by jc_builds.
      ```

- [x] Add `CHANGELOG.md` in Keep a Changelog format with a single `## [1.0.0] - 2026-08-18` entry
      under `### Added`, summarising the feature list from the README (marks and result builder,
      data-driven initializer, labelled values, implicit nodes, chart modifiers, selection,
      animation, accessibility, pure layout engine)
- [x] Add `CONTRIBUTING.md`: branch from `main` and open a PR (never commit to `main` directly),
      CI must be green, run `swiftlint --strict` before pushing, prefer testing through
      `SankeyGraph`/`SankeyLayout` rather than views, and never hand-edit the generated
      `SankeyDemo.xcodeproj` — edit `Examples/SankeyDemo/project.yml` and re-run `xcodegen generate`
- [x] Link `CHANGELOG.md` and `CONTRIBUTING.md` from the README's Development section
- [x] Open the PR with `gh pr create`

**Automated Verification**:
- [x] `git grep -n "$TEAM_ID"` returns nothing
- [x] `git grep -n "$HOME_PATH"` returns nothing
- [x] `git grep -nE '^git_commit: [0-9a-f]{7,}' -- docs` returns nothing
- [x] The number in `README.md:52` equals the count in
      `swift test 2>&1 | grep -oE 'with [0-9]+ tests' | grep -oE '[0-9]+'`
- [x] `grep -c 'offset in both axes' README.md` returns 0
- [x] `test -f CHANGELOG.md && test -f CONTRIBUTING.md && grep -q '1.0.0' CHANGELOG.md`
- [x] `swift build`, `swift test` and `swiftlint --strict` all pass
- [x] `swift package generate-documentation --target SankeyKit` succeeds
- [x] Every URL in the rewritten Credits section returns HTTP 200

---

### Phase 2: Five-platform CI matrix

Dependencies: Phase 1 (same branch and PR).

Prove the README's platform table on the GitHub runner, then make `Package.swift` and the README
agree with whatever the runner reports.

**Tasks**:
- [x] Add a `platforms` job to `.github/workflows/ci.yml`:

      ```yaml
        platforms:
          name: Build (${{ matrix.platform }})
          runs-on: macos-latest
          strategy:
            fail-fast: false          # one broken platform must not hide the others
            matrix:
              platform: [iOS, macOS, tvOS, watchOS, visionOS]
          steps:
            - uses: actions/checkout@v4
            - name: Select the newest Xcode
              run: sudo xcode-select -s "$(ls -d /Applications/Xcode_*.app | sort -V | tail -1)"
            - name: Build
              run: |
                xcodebuild build \
                  -scheme SankeyKit \
                  -destination "generic/platform=${{ matrix.platform }}"
      ```

- [x] Push and read every matrix leg's result
- [x] ~~If a leg fails with *"<platform> … is not installed"* rather than a compile error, the runner
      is missing the SDK, not the code: add
      `xcodebuild -downloadPlatform ${{ matrix.platform }}` as a step before the build and re-run.
      This is an environment fix, not a reason to drop the platform~~ — n/a, no leg was missing an SDK
- [x] ~~If a leg fails with a genuine compile error that an availability annotation or an
      `#if os(...)` guard resolves, fix it in `Sources/SankeyKit/` — the likely candidates are the
      `onTapGesture` calls at `SankeyDiagram.swift:33`, `:127` and `:159`, which today carry no
      platform guard at all~~ — n/a, no leg failed to compile
- [x] ~~If a leg needs structural change to compile, remove that platform from `Package.swift`,
      from the README requirements table and from
      `Sources/SankeyKit/Documentation.docc/SankeyKit.md:47-49`, and note it in `CHANGELOG.md` as a
      candidate for 1.1 — do not hold 1.0.0 for it~~ — n/a, all five platforms build
- [x] Merge the PR once every job is green

**Automated Verification**:
- [x] `gh pr checks` reports every job passing, including all five (or all remaining) matrix legs
- [x] The platform list in `Package.swift` matches the README requirements table:
      `swift package dump-package | jq -r '.platforms[].platformName' | sort` lines up with the
      table rows in `README.md`
- [x] `swift build`, `swift test` and `swiftlint --strict` still pass after any platform fix
- [x] `gh pr view --json state` reports `MERGED`

---

### Phase 3: History rewrite

Dependencies: Phase 2 merged into `main`.

Replace the employer email on every commit and scrub the Team ID and home path from historical file
contents, then force-push while the repository is still private.

**Tasks**:
- [x] `git switch main && git pull` so the merged PR is local
- [x] Back up first: `git bundle create <scratchpad>/sankeykit-pre-rewrite.bundle --all`, and record
      `git rev-parse main` so the pre-rewrite tip can be recovered
- [x] Confirm a clean tree (`git status --short` empty) — `--tree-filter` will not run otherwise
- [x] Delete the two stale local branches whose remotes are gone (decision 4):
      `git branch -D swiftui-way-audit-fixes fix/ios27-toggle-animation`
- [x] Set the local identity **before** rewriting, so nothing later reintroduces the work address:
      `git config --local user.email github@peterkurzok.de` and
      `git config --local user.name "Peter Kurzok"`
- [x] Run one combined pass:

      ```sh
      FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch \
        --env-filter '
          OLD="peter.kurzok@maibornwolff.de"
          NEW="github@peterkurzok.de"
          [ "$GIT_AUTHOR_EMAIL"    = "$OLD" ] && export GIT_AUTHOR_EMAIL="$NEW"
          [ "$GIT_COMMITTER_EMAIL" = "$OLD" ] && export GIT_COMMITTER_EMAIL="$NEW"
          true
        ' \
        --tree-filter '
          if [ -d docs ]; then
            find docs -name "*.md" -type f -exec sed -i "" \
              -e "s|$TEAM_ID|<your team ID>|g" \
              -e "s|$HOME_PATH/|the package root|g" {} +
          fi
          true
        ' \
        --tag-name-filter cat -- --all
      ```

      Both filters are single-quoted on purpose: `$TEAM_ID` and `$HOME_PATH` are **not** expanded
      by the outer shell, they are read from the environment by each filter invocation — so the two
      exports from the Placeholders section must still be live in this shell. Verify with
      `[ -n "$TEAM_ID" ] && [ -n "$HOME_PATH" ]` before running. The `true` at the end of each
      filter keeps a false `[ … ]` test from aborting the pass, and the `-d docs` guard exists
      because `docs/` is absent from the earliest commits.
- [x] Drop the backup refs `filter-branch` leaves behind:
      `git for-each-ref --format='%(refname)' refs/original | xargs -n 1 git update-ref -d`,
      then `git reflog expire --expire=now --all && git gc --prune=now --aggressive`
- [x] Force-push: `git push --force-with-lease origin main`

**Automated Verification**:
- [x] `git log --format='%ae %ce' --all | tr ' ' '\n' | sort -u` lists only
      `github@peterkurzok.de` and `noreply@github.com`
- [x] `git log -S "$TEAM_ID" --all --oneline` produces no output
- [x] `git log -S "$HOME_PATH" --all --oneline` produces no output
- [x] `git config --local user.email` prints `github@peterkurzok.de`
- [x] `git rev-list --count main` is identical to the count recorded before the rewrite
- [x] `git for-each-ref refs/original` is empty
- [x] `git status --short` is empty and `git diff origin/main` is empty after the push
- [x] `swift build && swift test && swiftlint --strict` still pass on the rewritten tree
- [x] `gh run list --branch main --limit 1` shows the post-force-push CI run green

---

### Phase 4: Publish and release

Dependencies: Phase 3 pushed and CI green.

Flip the repository to public, tag `1.0.0`, cut the Release, set the topics, then prove a real
consumer can resolve it.

**Tasks**:
- [x] `gh repo edit pkurzok/SankeyKit --visibility public --accept-visibility-change-consequences`
- [x] Set the topics:
      `gh repo edit pkurzok/SankeyKit --add-topic swift,swiftui,sankey,charts,data-visualization,swift-package`
- [x] Create the annotated tag on the rewritten `main`:
      `git tag -a 1.0.0 -m "SankeyKit 1.0.0"` — no `v` prefix, matching the
      `from: "1.0.0"` already written in `README.md:73`
- [x] `git push origin 1.0.0`
- [x] Extract the `1.0.0` section of `CHANGELOG.md` into a scratchpad file (everything between the
      `## [1.0.0]` heading and the next `## ` heading, heading excluded), then cut the Release:
      `gh release create 1.0.0 --title "SankeyKit 1.0.0" --notes-file <scratchpad>/release-notes.md`
- [x] Verify a real consumer resolves it: in the scratchpad, create a package with
      `dependencies: [.package(url: "https://github.com/pkurzok/SankeyKit.git", from: "1.0.0")]`
      and a target depending on the `SankeyKit` product, then `swift build`

**Automated Verification**:
- [x] `gh repo view pkurzok/SankeyKit --json visibility --jq .visibility` prints `PUBLIC`
- [x] `gh repo view pkurzok/SankeyKit --json repositoryTopics` lists all six topics
- [x] `git ls-remote --tags origin` lists `refs/tags/1.0.0`
- [x] `gh release view 1.0.0 --json tagName,name` returns tag `1.0.0` and name `SankeyKit 1.0.0`
- [x] The scratchpad consumer package builds, and its `Package.resolved` pins version `1.0.0`
- [x] `gh api repos/pkurzok/SankeyKit/community/profile --jq .health_percentage` returns a value
      reflecting the added README, LICENSE, CONTRIBUTING and CHANGELOG

**Manual Verification**:
- [x] Open `https://github.com/pkurzok/SankeyKit` while signed out (or in a private window) and
      confirm the README renders end to end: both `<picture>` elements resolve their light and dark
      screenshots, the badges load, and the Credits links work — relative image paths that render
      fine in a private repo can still surprise once the raw-content host changes.

## Implementation Notes

During implementation, document user feedback, problems, and decisions here.

**All five platforms compile.** The matrix went green on the first run — including tvOS and
watchOS, which the plan flagged as never having been built anywhere. No `#if os(...)` guard, no
availability annotation and no `-downloadPlatform` step was needed, so the three conditional
Phase 2 tasks are struck through as not applicable and `Package.swift` is untouched. 1.0.0 ships
the platform list it promises.

**The local git identity was set in Phase 1, not Phase 3.** The plan sequences
`git config --local user.email` inside the rewrite, but the Phase 1 and 2 commits would then have
carried the employer address into PR #5 and onto GitHub — briefly, and only while private, but
needlessly. Setting it before the first commit is strictly better and leaves the Phase 3 task
already satisfied.

**`filter-branch --all` rewrote `refs/remotes/origin/main` too**, so the plan's bare
`git push --force-with-lease origin main` would have compared the remote against a tracking ref
that no longer described it. The push was made as
`git push --force-with-lease=main:5015986 origin main` instead, pinning the expected value to the
real pre-rewrite tip, which restores the protection the plan wanted rather than defeating it.

**Every `git_commit:` frontmatter field under `docs/agents/plans/` was emptied, not just the three
the plan named.** `2026-08-17-curved-ribbons.md` and `2026-08-18-ribbon-node-overlap.md` also
carried SHAs; the plan's own verification (`git grep -nE '^git_commit: [0-9a-f]{7,}' -- docs`
returns nothing) requires all of them, and the rewrite invalidated every one.

**The Medium URL in Credits returns 403 to `curl`, not 200.** That is Medium's bot blocking, not a
dead link — the URL is byte-identical to the one already in the README before this work. The
d3-sankey URL returns 200.

**History rewriting, force-pushing and `chmod +x` were refused by the sandbox classifier.** The
rewrite was staged as `scratchpad/rewrite-history.sh` and run by the author, as was the force-push.
Everything either side of those two commands was automated.

**The public README was confirmed by the author** on 2026-08-18: it renders end to end signed out,
both `<picture>` elements swap their light and dark screenshots, the badges load and the Credits
links work. Checked ahead of that, anonymously: all seven images (both `~dark` variants included),
the CI badge and the release page return 200 over `raw.githubusercontent.com`.

**Community profile health is 57%** — README, LICENSE and CONTRIBUTING present. The remaining
items (code of conduct, issue and PR templates) are the ones this plan put out of scope.

## References

- Audit evidence gathered on 2026-08-18: `swift build` clean, `swift test` 112 tests in 13 suites,
  `swiftlint --strict` 0 violations, DocC archive generated.
- Local platform builds: `generic/platform=iOS` and `generic/platform=visionOS` succeed;
  `tvOS` and `watchOS` report *"tvOS 26.5 is not installed"* / *"watchOS 26.5 is not installed"* —
  a missing SDK, not a compile failure.
- `Sources/SankeyKit/Layout/RibbonGeometry.swift:44` — `controlPoints` offsets x only; its own doc
  comment already names `d3-shape`'s `bumpX`.
- `Sources/SankeyKit/View/SankeyChart+Accessibility.swift:73,104` — `.accessibilityAction` and the
  `.isButton` trait, added in PR #3, are what make the tvOS README sentence stale.
- `docs/agents/plans/2026-08-17-curved-ribbons.md` — the decision record for replacing the Medium
  article's formula with `d3-shape`'s `bumpX`.
- `CLAUDE.md` — the branch-then-PR convention that `CONTRIBUTING.md` restates publicly.
- Keep a Changelog: <https://keepachangelog.com/en/1.1.0/>
