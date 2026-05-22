# Roadmap

## Phase 1: Runnable MVP

Goal: create a working local macOS app with real scan and safe cleanup.

Tasks:

1. Create SwiftUI project structure.
2. Build premium shell UI with sidebar.
3. Add Smart Care, Cleanup, Applications, Space Lens, and Activity views.
4. Implement scanner for `~/Library/Caches`, `~/Library/Logs`, and `~/.Trash`.
5. Calculate file/folder sizes.
6. Show scan results and total reclaimable size.
7. Allow selecting results.
8. Move selected items to Trash.
9. Add in-memory activity log.
10. Verify with `swift build`.

## Phase 2: Better Product Feel

Goal: make the MVP feel more like a polished utility.

Tasks:

1. Progress state during scan. Done for main scan and Space Lens basic state.
2. Better grouped result list. Done for Cleanup categories.
3. Per-category result counts. Done in Cleanup category headers.
4. Error handling per file/folder. Done; failed items are surfaced with reason and path.
5. Empty states. Done for current modules.
6. Confirmation dialog. Done for cleanup.
7. Scan result sorting. Partial; results are sorted by size.
8. Folder picker for Space Lens. Done.
9. External disk support for `/Volumes/My Disk (aldy_uhaa)/`. Possible through Choose Folder, not yet preset.
10. Persist activity log. Done via local JSON in Application Support.

## Phase 3: Applications Tools

Goal: make the Applications module useful.

Tasks:

1. List installed apps from `/Applications` and `~/Applications`.
2. Calculate app bundle sizes.
3. Detect obvious leftovers by bundle/app name. Done with conservative user-level scanning.
4. Show uninstall checklist. Done with selectable app rows.
5. Move selected leftovers to Trash. Done with confirmation and safety labels.
6. Group leftovers by app hint. Done.
7. Avoid auto-selecting caution leftovers. Done.

## Phase 4: Clutter Tools

Goal: help Aldy find large personal files without deleting automatically.

Tasks:

1. Large file finder.
2. Downloads review.
3. Screenshot review.
4. Similar image finder, if needed.
5. Duplicate finder, if needed.

## Phase 5: App Packaging

Goal: make the app convenient to launch.

Tasks:

1. Create Xcode project or package app bundle. Done via script-based packaging.
2. Add app icon. Pending.
3. Add entitlements if needed. Pending; current app does not use custom entitlements.
4. Create `.app` bundle. Done at `dist/Mac Cleaner.app`.
5. Optional local code signing. Done with ad-hoc signing.
6. Optional DMG packaging. Pending.

## Shareable Beta Polish

Completed:

1. Applications Manager can uninstall selected apps by moving them to Trash.
2. Leftover Files are grouped and labeled as Safe or Review.
3. Broad leftover selection only selects Safe items.
4. Cleanup/uninstall/leftover failures show details in the app.
5. Smart Care includes cleanup, app, leftover, and last action metrics.

Pending:

1. Custom app icon.
2. DMG packaging.
3. Notarized signing workflow if this becomes public.

## Known Environment Note

Current machine has Apple Swift command line tools, but `xcodebuild` reports that full Xcode is not selected/available. `swift build` can be used for code verification if SwiftUI compiles with the installed SDK. Full `.app` packaging may require installing/opening Xcode later.
