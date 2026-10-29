# RemoveMacAI, Ventura variant

A Ventura (macOS 13) build of RemoveMacAI, forked from upstream
[omlahore/RemoveMacAI](https://github.com/omlahore/RemoveMacAI) at `afdac00`
(MIT). Upstream requires macOS 15.1+ because Apple Intelligence starts
there; on Ventura there is no Apple Intelligence to turn off, so this
variant is the rest of the tool: the privacy, annoyance, Finder, Dock,
typing, background-item and storage tweaks, with undo.

## What changed from upstream (6 files)

- `Package.swift`: platform floor `macOS 15.1` -> `13.0`.
- `Sources/removemacai/main.swift`: run gate `15.1` -> `13.0`.
- `tools/build-app.sh`: `LSMinimumSystemVersion` `15.1` -> `13.0`, and
  the build arch is now `REMOVEMACAI_ARCH` (default `arm64`;
  `x86_64` for an Intel Ventura Mac).
- `Sources/removemacai/Tweaks.swift`: default tweak floor `14.0` ->
  `13.0`, with `click-to-desktop` and `desktop-widgets` explicitly kept
  at `14.0` (their WindowManager keys are Sonoma-only). The three
  already-gated `15.0` tweaks (`iphone-mirroring`, `book-store`,
  `tile-margins`) stay hidden on Ventura.
- `Sources/removemacai/Commands.swift`: version `1.2.0-ventura.2`, so
  this build never reports itself as an upstream release.
- `Sources/removemacai/Updates.swift`: Check for Updates scans this
  fork's releases list newest-first and only offers tags carrying
  `ventura`. It never offers an upstream build, which needs macOS
  15.1+. (The workflow marks Ventura builds pre-release because
  their tags carry a dash, and GitHub's "latest" endpoint skips
  pre-releases, so the list scan is what makes the check work at
  all.) URLs point at the proposed fork, `Salcedoandrew/RemoveMacAI`;
  if the fork lands under another name, those two lines change.
- `.github/workflows/release.yml`, `.github/workflows/ci.yml`:
  `tools/build-app.sh` is now run via `bash`, and the release
  publish step uploads into a web-created release when one already
  exists, because snapshot pushes carry no file modes (the script
  could lose its executable bit) and the connector has no tag tool.

Remote-branch note: the `ventura` branch on the fork was pushed via
a file snapshot, so it holds one commit containing this tree, not
the local commit history.

## What deliberately did not change

- AI features: they already hide themselves per OS version
  (`Catalog.Feature.since`, default 15.1), so on Ventura
  `availableFeatures` is empty and the generated profile contains no
  Apple Intelligence keys. No AI code was touched.
- Bundle id and journal path are unchanged, so undo history stays
  compatible with the upstream layout.
- No upstream files were pushed anywhere. This tree is local only
  until the owner approves a fork.

## Release flow (fork + CI, Apple silicon)

1. Fork to `Salcedoandrew/RemoveMacAI`, push branch `ventura`.
2. Fresh forks ship with Actions disabled behind TWO gates, and both
   must be cleared, or the tag push builds nothing:
   (a) the Actions-tab banner "Workflows aren't being run on this
   forked repository" — click "I understand my workflows, go ahead
   and enable them" (this is the gate that actually blocks runs);
   (b) Settings > Actions > Allow all actions and reusable workflows.
   If a tag push fired while the banner gate was still up, no run is
   created retroactively. The manual "Run workflow" button is not a
   fallback here either: GitHub only offers it when the workflow file
   on the DEFAULT branch has a `workflow_dispatch` trigger, and this
   fork keeps the variant on `ventura`. The working fix is a fresh
   tag push after enabling — which is why the first CI-built release
   is `1.2.0-ventura.2` (the `.1` release predates the enabling and
   has no assets; the workflow still carries the dispatch trigger
   for future use if the variant is ever merged to main).
3. Create the release in the web UI (the connector has no tag tool):
   tag `v1.2.0-ventura.2`, target branch `ventura`, title
   `v1.2.0-ventura.2`, notes from the `## 1.2.0-ventura.2`
   CHANGELOG section, marked pre-release. Creating it creates the
   tag, which triggers the Release workflow on macos-26: build,
   then `selftest` (a failure blocks publishing), then packaging
   and upload of the CLI tarball and `RemoveMacAI.zip` plus SHA-256
   files into that release (the workflow's publish step uploads
   when the release already exists instead of failing on
   `gh release create`). The dash in the tag is what marks it
   pre-release, which is correct for a variant build.
4. First run on the Ventura Mac should still be `removemacai status`
   and `removemacai tweaks`, then one low-risk tweak with `undo`,
   before any preset: CI proves the macOS 13 target compiles, not
   that every tweak behaves on Ventura.

## What is NOT verified yet

- Compile: this VM is Linux with no Swift toolchain, so the macOS 13
  deployment target has not been compiled. The SwiftUI app code may
  use APIs newer than 13 that only a build will surface.
- Runtime: nothing has run on a Ventura Mac yet. First run should be
  `removemacai status` and `removemacai tweaks`, then one low-risk
  tweak with `undo`, before any preset.
- Intel: an `x86_64` build has not been produced or tested.

## Build (on a Mac, or CI on a macOS runner)

```sh
swift build -c release --arch arm64   # or REMOVEMACAI_ARCH=x86_64
tools/build-app.sh                    # -> .build/RemoveMacAI.app
```

Ad-hoc signed, not notarized: right-click Open on first launch.
