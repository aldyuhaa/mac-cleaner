# Safety Model

## Core Rule

The app must never behave like a blind delete script. It must scan, explain, then clean only user-approved items.

## Cleanup Method

The app must move selected items to Trash using macOS APIs where possible.

Permanent deletion is deferred.

## Safety Levels

### Safe

Normally okay to remove after review.

Examples:

1. Top-level folders/files inside `~/Library/Caches`.
2. Files inside `~/.Trash`.
3. Logs inside `~/Library/Logs`.
4. App leftover cache/log/saved-state items in user-level Library folders.

### Caution

Can be removed, but may affect app state or require closing apps first.

Examples:

1. Browser cache while browser is open.
2. Large app-specific cache folders.
3. Temporary files with unclear owner.
4. App leftover preferences, containers, and application support items.

### Protected

Must not be removed by MVP.

Examples:

1. `/System`.
2. `/Library`.
3. `/private`.
4. Root-owned system directories.
5. Any path outside explicit allowlist.

## Initial Allowlist

The MVP may scan these paths:

1. `~/Library/Caches`.
2. `~/Library/Logs`.
3. `~/.Trash`.

Applications Manager may also scan these user-level paths for reviewable leftovers:

1. `~/Library/Application Support`
2. `~/Library/Caches`
3. `~/Library/Logs`
4. `~/Library/Preferences`
5. `~/Library/Saved Application State`
6. `~/Library/Containers`

The MVP may display sizes from these locations, but cleanup must still require user selection and confirmation.

Application Support, Preferences, and Containers leftovers are review/caution items. They must not be selected as part of a broad "Select Safe" action.

## Initial Blocklist

Never clean these paths in MVP:

1. `/System`.
2. `/Library`.
3. `/Applications`.
4. `/bin`.
5. `/sbin`.
6. `/usr`.
7. `/private`.
8. `~/Documents`.
9. `~/Desktop`.
10. `~/Downloads`.

## Confirmation Copy

Before cleanup, show a confirmation that says the app will move selected items to Trash and that the user can restore them from Trash if needed.

## Failure Handling

If moving an item to Trash fails, the app should keep going with the remaining selected items and show the failed item name, path, and macOS error reason in the UI.

## Activity Logging

Every cleanup should be recorded in memory first. Later versions may persist logs to a local JSON file.
