#!/usr/bin/env bash
# Builds the Windows release of Fluffy Horror Bears into dist/:
#   dist/FluffyHorrorBears.exe                     (export, the game data embedded)
#   dist/FluffyHorrorBears-<version>-win64.zip     (portable: just the EXE)
#   dist/FluffyHorrorBears-<version>-setup.exe     (Inno Setup installer, if ISCC is available)
#
# Usage: tools/build_windows.sh [path/to/godot]
#   GODOT  Godot 4.3 editor binary (default: godot on PATH). Needs the 4.3 export
#          templates installed (Editor > Manage Export Templates).
#   ISCC   Inno Setup compiler. On Windows: ISCC.exe on PATH or in the default
#          install folder. On Linux/macOS: "wine <path>/ISCC.exe".
# The version comes from application/config/version in project.godot.
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="${1:-${GODOT:-godot}}"
VERSION=$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)
[ -n "$VERSION" ] || { echo "no config/version in project.godot" >&2; exit 1; }
echo "Fluffy Horror Bears $VERSION"

mkdir -p dist
rm -f dist/FluffyHorrorBears.exe
"$GODOT" --headless --export-release "Windows Desktop" dist/FluffyHorrorBears.exe
[ -s dist/FluffyHorrorBears.exe ] || { echo "export failed" >&2; exit 1; }

ZIP="dist/FluffyHorrorBears-$VERSION-win64.zip"
rm -f "$ZIP"
(cd dist && zip -q -9 "$(basename "$ZIP")" FluffyHorrorBears.exe)
echo "portable: $ZIP"

if [ -z "${ISCC:-}" ]; then
	if command -v iscc >/dev/null 2>&1; then ISCC=iscc
	elif command -v ISCC.exe >/dev/null 2>&1; then ISCC=ISCC.exe
	elif [ -x "/c/Program Files (x86)/Inno Setup 6/ISCC.exe" ]; then ISCC="/c/Program Files (x86)/Inno Setup 6/ISCC.exe"
	fi
fi
if [ -n "${ISCC:-}" ]; then
	# paths relative to the .iss file (installer/), with Windows separators
	$ISCC /Q "/DAppVersion=$VERSION" '/DSourceExe=..\dist\FluffyHorrorBears.exe' '/DOutputDir=..\dist' installer/FluffyHorrorBears.iss
	echo "installer: dist/FluffyHorrorBears-$VERSION-setup.exe"
else
	echo "ISCC not found: installer skipped (set ISCC=... to build it)"
fi
ls -la dist
