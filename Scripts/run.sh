#!/bin/bash
# Rebuilds and restarts BarMod.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/Scripts/build.sh"
pkill -x BarMod || true
open "$ROOT/build/BarMod.app"
