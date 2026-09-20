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
`Layout.availableWidth` (left bound = `NSScreen.auxiliaryTopRightArea?.minX ?? screen.minX`; only
visible-section items left of the toggle count).
- fits and `alwaysUseBar == false` → `setState(.expanded)`
- else → `OverflowPanel.show` with hidden(+always hidden when ⌥) items
Click ⌃ while expanded/all or panel visible → collapse / hide panel.

## Overflow bar
`NSPanel`, non-activating, level `.popUpMenu`, 22 pt-high cells (app icon + item title), hover highlight,
dismiss on click-outside / Esc. Two placements, decided per show:
1. **Left of the notch, inside the menu bar** (Ice / Bartender style): one row, no backdrop, menu-bar height,
   right-aligned to `auxiliaryTopLeftArea.maxX` with `Layout.notchGap` clear of the notch and of the frontmost
   app's last menu title (`ItemScanner.frontmostMenuMaxX`, AX `AXMenuBar`). `Layout.leftOfNotchX` returns
   `nil` when the row does not fit.
2. **Fallback** (no notch, or does not fit): right-aligned under the toggle, wraps if wider than 80 % of the
   screen, translucent backdrop.
Click → `ItemClicker.click`: reveal section, poll until item on screen, post CGEvent click at its centre.
Still off screen (macOS overflow) → `kAXPressAction` on the item's element (menu may open at screen edge).
After a forwarded click the bar stays expanded until the user collapses it (`ponytail:`).

## Item discovery (macOS 26 findings, verified 2026-09-18)
- The window list is useless: every status item window on layer 25 is owned by Control Center, names are
  "Item-0", and `NSStatusItem.button.window.windowNumber` is not a `CGWindowID` (64-bit, traps on conversion).
- Off-screen (spacer-pushed) item windows cannot be captured: ScreenCaptureKit `desktopIndependentWindow`
  fails with -3811, display filter returns a transparent image. Hence no thumbnails.
- Items macOS itself drops behind the notch keep a positive x but are not on screen.
- Therefore items come from Accessibility: per running app (`activationPolicy != .prohibited`, plus
  Control Center) `AXExtrasMenuBar` → children with position/size/title; messaging timeout 0.2 s.
  `isOnScreen` = frame inside `[leftBound, screen.maxX]`.

## Permissions
- Accessibility only: item discovery, synthetic clicks, AX press. Requested on first toggle; until granted
  the toggle simply expands in place (no fit check, no bar).

## Menu (right-click ⃣ toggle)
Show/Hide Hidden Items · Show All Items · Always Use Bar ☐ · Launch at Login ☐ · Quit

## Module map
| File | Owns |
|---|---|
| `Core/Layout.swift` | `Section`, `BarState`, pure geometry (tested) |
| `Core/MenuBarItem.swift` | value type for other apps' items |
| `Core/ItemScanner.swift` | AX scan of every app's `AXExtrasMenuBar` |
| `Core/ItemClicker.swift` | click forwarding |
| `System/Permissions.swift`, `System/LoginItem.swift` | Accessibility TCC + login item |
| `UI/StatusBarController.swift` | three status items, states, menu |
| `UI/OverflowPanel.swift` | floating bar |
| `AppDelegate.swift`, `main.swift` | wiring |

## Build / test
`make` build · `make test` (passes Swift Testing plugin path) · `make install` → `~/Applications/Notchy.app`.
Debug: `open --env NOTCHY_DEBUG=1 ~/Applications/Notchy.app`, log at `~/Library/Logs/Notchy/debug.log`.
