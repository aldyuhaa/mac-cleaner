# Mac Cleaner

Native macOS cleaner app for Aldy. The app is inspired by the premium workflow of CleanMyMac, but scoped as a safer personal utility first.

## What Exists Now

1. SwiftUI macOS project using Swift Package Manager.
2. Premium sidebar layout with module themes.
3. Smart Care dashboard.
4. Cleanup scan for safe user-level locations.
5. Applications inventory from `/Applications` and `~/Applications`.
6. Space Lens placeholder using largest scan results.
7. Activity log for scans and cleanup actions.
8. Cleanup confirmation dialog.
9. Cleanup moves selected items to Trash, not permanent delete.
10. Cleanup results grouped by category.
11. Space Lens folder picker and home folder scan.
12. Activity history persisted locally to Application Support.
13. Applications Manager with selectable app uninstall to Trash.
14. Leftover Files review grouped by app hint with Safe/Review labels.
15. Operation failure details shown in the app after cleanup/uninstall actions.

## Safe Scan Locations

The MVP scans:

1. `~/Library/Caches`
2. `~/Library/Logs`
3. `~/.Trash`

The MVP does not clean system directories or sensitive user data locations.

## Applications Manager

The Applications tab can:

1. List installed apps from `/Applications` and `~/Applications`.
2. Move selected `.app` bundles to Trash after confirmation.
3. Detect likely leftover files from user-level Library locations.
4. Group leftovers by app hint and show safety labels.
5. Move selected leftover items to Trash after confirmation.

Leftover detection is heuristic. Cache, logs, and saved state are treated as safer; preferences, containers, and application support items are marked for review and must be selected deliberately.

## Run Locally

From this folder:

```bash
swift run
```

To verify compile only:

```bash
swift build
```

## Build `.app`

From this folder:

```bash
./scripts/package_app.sh
```

The generated app is:

```text
dist/Mac Cleaner.app
```

You can double click that `.app` from Finder. If macOS warns because this is locally built and not notarized, right-click the app, choose `Open`, then confirm.

## Share to Other People (Free Path)

Use this to generate a shareable zip and checksum:

```bash
./scripts/release_free.sh
```

Generated files:

```text
dist/release/Mac-Cleaner.zip
dist/release/Mac-Cleaner.sha256
```

How to share:

1. Upload `Mac-Cleaner.zip` and `Mac-Cleaner.sha256` to GitHub Release or cloud storage.
2. Share both files to users.

How users verify checksum:

```bash
shasum -a 256 -c Mac-Cleaner.sha256
```

If output is `OK`, the file matches your original build.

## End User Install

1. Download `Mac-Cleaner.zip`.
2. Extract the zip.
3. Move `Mac Cleaner.app` into `Applications` (optional but recommended).
4. First launch: right-click app -> `Open` -> confirm.

## Packaging Note

SwiftUI does not need a separate install. It comes with Apple's macOS SDK.

This machine currently has Apple Swift command line tools and can build the project with `swift build`. Full Xcode is not currently selected, so `xcodebuild` cannot create an Archive workflow yet.

A local `.app` packaging script now exists at `scripts/package_app.sh`. It creates an ad-hoc signed app bundle suitable for personal local testing. It is not notarized for public distribution.

## Important Docs

Read these before continuing in a new session:

1. `PROJECT_BRIEF.md`
2. `Docs/DESIGN_SYSTEM.md`
3. `Docs/SAFETY_MODEL.md`
4. `Docs/ROADMAP.md`

## Next Best Tasks

1. Add app icon and refined visual assets.
2. Add DMG packaging after the app is visually stable.
3. Add progress detail/cancel for long Space Lens scans.
4. Add deeper app-specific leftover matching for selected apps.
5. Add result sorting and filtering controls.
