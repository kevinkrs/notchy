#!/usr/bin/env bash
# Build Notchy.app from the SwiftPM release binary.
# Usage: scripts/build-app.sh [VERSION]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Marketing version: latest tag (without leading v) or 0.1.0. Build number: commit count.
VERSION="${1:-$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || true)}"
VERSION="${VERSION:-0.1.0}"
BUILD="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
APP="build/Notchy.app"
CONTENTS="$APP/Contents"

swift build -c release --product Notchy
BIN="$(swift build -c release --show-bin-path)/Notchy"

rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

cp "$BIN" "$CONTENTS/MacOS/Notchy"
sed -e "s/__VERSION__/$VERSION/g" -e "s/__BUILD__/$BUILD/g" Resources/Info.plist > "$CONTENTS/Info.plist"
echo -n 'APPL????' > "$CONTENTS/PkgInfo"

codesign --force --sign - --timestamp=none "$APP"

echo "$ROOT/$APP"
