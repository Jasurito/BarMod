#!/bin/bash
# Runs unit tests. Command Line Tools ship Swift Testing outside SwiftPM's default paths.
set -euo pipefail

cd "$(dirname "$0")/.."
TOOLS=/Library/Developer/CommandLineTools/Library/Developer
swift test \
  -Xswiftc -F -Xswiftc "$TOOLS/Frameworks" \
  -Xlinker -F -Xlinker "$TOOLS/Frameworks" \
  -Xlinker -rpath -Xlinker "$TOOLS/Frameworks" \
  -Xlinker -rpath -Xlinker "$TOOLS/usr/lib"
