# Design System

## Visual Direction

The app should feel like a premium macOS utility inspired by CleanMyMac screenshots shared by Aldy:

1. Large rounded window.
2. Left sidebar navigation.
3. Saturated gradient backgrounds per module.
4. Big center/hero area.
5. Prominent circular scan button.
6. Soft glow and glass-like cards.
7. Clear module title and short description.

Do not copy CleanMyMac exactly. Use the same interaction pattern, but create original copy, naming, and visual details.

## Layout

Window target:

1. Minimum width: around 1080 px.
2. Minimum height: around 720 px.
3. Sidebar width: around 250 px.
4. Main content fills the rest.

Primary layout:

1. Sidebar on the left.
2. Module hero in main content.
3. Scan button anchored near bottom center.
4. Results panel appears after scan.

## Sidebar Modules

Initial modules:

1. Smart Care.
2. Cleanup.
3. Applications.
4. Space Lens.
5. Activity.

Possible later modules:

1. Performance.
2. Protection.
3. My Clutter.
4. Cloud Cleanup.

## Color Themes

Use module-specific themes:

1. Smart Care: purple/magenta.
2. Cleanup: green/emerald.
3. Applications: blue/cyan.
4. Space Lens: violet/indigo.
5. Activity: slate/teal.

## Component Style

Cards:

1. Rounded corners.
2. Subtle translucent background.
3. Thin white border with low opacity.
4. Soft shadow.

Buttons:

1. Main scan button should be circular or pill-circle hybrid.
2. Secondary actions use rounded rectangles.
3. Destructive cleanup actions should be visually distinct but not alarming.

Typography:

1. Use system font.
2. Large module titles.
3. Compact result rows.
4. Clear size labels.

## Interaction Model

Default flow:

1. User opens app.
2. Smart Care selected.
3. User clicks Scan.
4. App scans allowed paths.
5. App shows grouped results.
6. User reviews and selects items.
7. User clicks Clean Selected.
8. App moves selected items to Trash.
9. Activity log updates.

## Empty States

Before scan:

1. Show module description.
2. Show feature bullets.
3. Encourage pressing Scan.

After scan with no results:

1. Show positive clean-state message.
2. Keep scan button available.

After scan with results:

1. Show total reclaimable space.
2. Show result list.
3. Show safety labels.
