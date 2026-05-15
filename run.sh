#!/bin/bash
set -e
cd "$(dirname "$0")"

swift build 2>&1 | tail -3

APP=".build/Mnemox.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/debug/mnemox "$APP/Contents/MacOS/Mnemox"
cp Support/MnemoxEmbeddedInfo.plist "$APP/Contents/Info.plist"

open "$APP"
