# Notchy

Tiny Bartender / Ice replacement. Hides menu bar items, three sections, overflow bar so nothing vanishes behind the notch.

## Use
- Click `»` to show hidden items. As many as fit appear right of the notch; the rest appear in the free
  menu bar space left of the notch (or below the menu bar if there is no room). Click one to use it.
- Right-click `»` → Show All Items: every hidden and always-hidden item in a bar below the menu bar.
- To arrange: `⌥`-click `»` (shows everything in place, both dividers visible), then `⌘`-drag items:
  `[always hidden] ⸰ [hidden] | [visible] »`. Dragging while a section is collapsed lands items in the wrong section.
- Right-click `»`: Always Use Bar, Launch at Login, Quit.

## Permission (asked on first toggle)
- Accessibility: finding other apps' items and forwarding clicks. Without it Notchy just expands in place.

## Build
```
make            # swift build
make test
make install    # ~/Applications/Notchy.app
```
Command Line Tools are enough, no Xcode needed.

Ad-hoc signing changes the binary hash on every build, and macOS then forgets the Accessibility grant.
For a stable identity create a self-signed code-signing certificate named `Notchy Dev` (Keychain Access →
Certificate Assistant → Create a Certificate, type Code Signing) and build with `CODESIGN_ID="Notchy Dev" make install`. Spec: `docs/spec.md`.
