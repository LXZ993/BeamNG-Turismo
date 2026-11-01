#!/usr/bin/env bash
# Builds dist/turismo_karriere.zip from mod/ (runs the tests first).
set -euo pipefail
cd "$(dirname "$0")/.."
luajit tools/test/unit.lua > /dev/null
luajit tools/test/smoke.lua > /dev/null
for f in $(find mod/lua -name '*.lua'); do luajit -bl "$f" > /dev/null; done
mkdir -p dist
rm -f dist/turismo_karriere.zip
(cd mod && zip -qr -X ../dist/turismo_karriere.zip . -x '*.DS_Store')
echo "dist/turismo_karriere.zip ($(du -h dist/turismo_karriere.zip | cut -f1))"
