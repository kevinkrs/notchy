# Notchy – Spec

Menu bar organiser (Bartender / Ice lite). Native Swift, SwiftPM only, macOS 14+, Command Line Tools build.

## Goals
- a) Start at login (`SMAppService.mainApp`).
- b) Sort items: native ⌘-drag. No custom UI.
- c) Three sections: visible, hidden, always hidden.
- d) Toggling hidden never loses items behind the notch: overflow bar shows all of them.

## Non-goals (v1)
Hotkeys, auto-rehide timer, multi-display, per-app rules, settings window, custom icons.

## Mechanism
Notchy owns three `NSStatusItem`s. Right→left: `toggle` (chevron) | `hidden spacer` | `always-hidden spacer`.
A spacer with length 10000 pushes everything left of it off screen (Hidden Bar / Ice trick).

| State | hidden spacer | always-hidden spacer | shows |
|---|---|---|---|
| collapsed (default) | 10000 | 8 | visible |
| expanded (click ⌃) | 8 | 10000 | visible + hidden |
| all (⌥-click ⌃) | 8 | 8 | everything |

Sections = position of other apps' items relative to the spacers (`Layout.section`). Nothing persisted;
macOS remembers positions. First launch seeds `NSStatusItem Preferred Position <autosaveName>` defaults so
spacers start left of the toggle.

## Toggle behaviour (auto mode)
Click ⌃ while collapsed: scan items (`ItemScanner`), sum widths of hidden section, compare with
`Layout.availableWidth` (left bound = `NSScreen.auxiliaryTopRightArea?.minX ?? screen.minX`).
- fits and `alwaysUseBar == false` → `setState(.expanded)`
- else → `OverflowPanel.show` with hidden(+always hidden when ⌥) items and `ItemCapture` thumbnails
Click ⌃ while expanded/all or panel visible → collapse / hide panel.

## Overflow bar
`NSPanel`, non-activating, level `.popUpMenu`, right-aligned under the toggle, one row of 22 pt-high
thumbnails (wraps if wider than screen), hover highlight, dismiss on click-outside / Esc.
Click → `ItemClicker.click`: reveal section, poll until item on screen, post CGEvent click at its centre.
Still off screen (macOS overflow) → AX press fallback (menu may open at screen edge).
After a forwarded click the bar stays expanded until the user collapses it (`ponytail:`).

## Permissions
- Screen Recording: thumbnails (`ScreenCaptureKit`, `SCContentFilter(desktopIndependentWindow:)`).
  Without it: fall back to owner app icon + name.
- Accessibility: synthetic clicks. Without it: clicking a thumbnail just expands the section.
Both requested lazily on first use.

## Menu (right-click ⃣ toggle)
Show/Hide Hidden Items · Show All Items · Always Use Bar ☐ · Launch at Login ☐ · Quit

## Module map
| File | Owns |
|---|---|
| `Core/Layout.swift` | `Section`, `BarState`, pure geometry (tested) |
| `Core/MenuBarItem.swift` | value type for other apps' items |
| `Core/ItemScanner.swift` | `CGWindowListCopyWindowInfo` layer 25 |
| `Core/ItemCapture.swift` | ScreenCaptureKit thumbnails |
| `Core/ItemClicker.swift` | click forwarding |
| `System/Permissions.swift`, `System/LoginItem.swift` | TCC + login item |
| `UI/StatusBarController.swift` | three status items, states, menu |
| `UI/OverflowPanel.swift` | floating bar |
| `AppDelegate.swift`, `main.swift` | wiring |

## Build / test
`make` build · `make test` (passes Swift Testing plugin path) · `make install` → `~/Applications/Notchy.app`.
Debug: `open --env NOTCHY_DEBUG=1 ~/Applications/Notchy.app`, log at `~/Library/Logs/Notchy/debug.log`.
