# Notchy

Tiny Bartender / Ice replacement. Hides menu bar items, three sections, overflow bar so nothing vanishes behind the notch.

## Use
- To arrange: `⌥`-click `⌃` first (shows everything, both dividers visible), then `⌘`-drag items:
  `[always hidden] ⸰ [hidden] | [visible] ⌃`. Dragging while a section is collapsed lands items in the wrong section.
- Click `⌃` to show hidden items. `⌥`-click shows always-hidden too.
- Too many items to fit? Notchy opens a bar below the menu bar with all of them instead. Click one to use it.
- Right-click `⌃`: Always Use Bar, Launch at Login, Quit.

## Permission (asked on first toggle)
- Accessibility: finding other apps' items and forwarding clicks. Without it Notchy just expands in place.

## Build
```
make            # swift build
make test
make install    # ~/Applications/Notchy.app
```
Command Line Tools are enough, no Xcode needed. Spec: `docs/spec.md`.
