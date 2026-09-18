# Notchy

Tiny Bartender / Ice replacement. Hides menu bar items, three sections, overflow bar so nothing vanishes behind the notch.

## Use
- `⌘`-drag items in the menu bar to sort them and move them across Notchy's two invisible spacers:
  `[always hidden] | [hidden] | [visible] ⌃`
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
