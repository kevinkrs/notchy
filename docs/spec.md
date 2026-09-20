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

## Toggle behaviour
Click ⌃ while collapsed → `setState(.expanded)`: macOS shows as many hidden items as fit right of the notch,
the rest stay behind the notch (reachable via Show All). ⌥-click → same with `.all` (arrange mode: both
dividers visible for ⌘-drag). `alwaysUseBar` → hidden items go to the bar left of the notch, nothing expands.
Click ⌃ while expanded/all or panel visible → collapse / hide panel.
Right-click → "Show All Items": every hidden + always-hidden item in the panel *below* the toggle
(`below: true`), menu bar untouched. Without Accessibility the toggle simply expands in place.

## Overflow bar
`NSPanel`, non-activating, level `.popUpMenu`, 22 pt square cells (app icon, title in tooltip), hover highlight,
dismiss on click-outside / Esc. Two placements, decided per show:
1. **Left of the notch, inside the menu bar** (Ice / Bartender style): one row, no backdrop, menu-bar height,
   right-aligned to `auxiliaryTopLeftArea.maxX` with `Layout.notchGap` clear of the notch and of the frontmost
   app's last menu title (`ItemScanner.frontmostMenuMaxX`, AX `AXMenuBar`). `Layout.leftOfNotchX` returns
   `nil` when the row does not fit.
2. **Below the toggle** (`below: true`, no notch, or does not fit): right-aligned under the toggle, wraps if wider than 80 % of the
   screen, translucent backdrop.
Click → `ItemClicker.click`: reveal section, poll until item on screen, post CGEvent click at its centre.
Still off screen (macOS overflow) → `kAXPressAction` on the item's element (menu may open at screen edge).
After a forwarded click the bar stays expanded until the user collapses it (`ponytail:`).
Cells are in menu bar order with a 1 pt separator where the section changes (always hidden ⸰ hidden).
Right-click a cell → Move to Visible / Hidden / Always Hidden → collapse (400 ms), then `ItemMover.move`,
Ice's recipe (verified working on macOS 26.7, 2026-09-20; every simplification of it failed):
- `CGEventSource(stateID: .hidSystemState)`, local-events filter permit-all for `remoteMouseDrag` and
  `suppressionInterval`, interval 0.
- Item window = layer-25 window (`CGWindowListCopyWindowInfo(.optionAll)`, includes off-screen) whose bounds
  contain the item's AX frame; owner is Control Center on macOS 26.
- ⌘-mouse-down at the bogus point (20000, 20000): routing is done purely by the stamped fields
  `eventTargetUnixProcessID`, `mouseEventWindowUnderMousePointer(ThatCanHandleThisEvent)`, private field 0x33
  (window id), `eventSourceUserData`. No hit test, so off-screen items work.
- Mouse-up (no flags) at `destinationX` (hidden divider maxX+4 → visible, hidden divider minX−4 → hidden,
  always-hidden divider minX−4 → always hidden), stamped with the window at that point (our spacer).
- No dragged events. Posted to `.cgSessionEventTap` (odd attempts) / `postToPid` (even), 4 attempts, success =
  frame changed. Cursor restored. Collapsing first keeps everything grabbable (nothing under the notch).
  Show All reopens afterwards.

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
| `Core/ItemMover.swift` | section moves via synthetic ⌘-drag |
| `System/Permissions.swift`, `System/LoginItem.swift` | Accessibility TCC + login item |
| `UI/StatusBarController.swift` | three status items, states, menu |
| `UI/OverflowPanel.swift` | floating bar |
| `AppDelegate.swift`, `main.swift` | wiring |

## Build / test
`make` build · `make test` (passes Swift Testing plugin path) · `make install` → `~/Applications/Notchy.app`.
Debug: `open --env NOTCHY_DEBUG=1 ~/Applications/Notchy.app`, log at `~/Library/Logs/Notchy/debug.log`.
