#!/usr/bin/env bash
# Build this checkout (the `patched` branch: an upstream release tag plus local
# fixes), sign it with the local "Rift Local Signing" identity, and install it
# over the Homebrew Rift.app that `brew services` runs.
#
# Upgrading to a new upstream release:
#   git fetch upstream --tags && git rebase --onto vX.Y.Z vOLD patched
#   brew upgrade acsandmann/tap/rift && scripts/install-patched.sh
#
# Signing: the Accessibility grant is tied to the signing certificate. The
# identity lives in ~/Library/Keychains/rift-local.keychain-db; its password is
# the login-keychain item "rift-local-keychain". Builds signed with it keep the
# grant. After running an upstream build (brew upgrade/reinstall), run
# `tccutil reset Accessibility git.acsandmann.rift` and re-enable Rift in
# System Settings > Privacy & Security > Accessibility once.
set -euo pipefail

src="$(cd "$(dirname "$0")/.." && pwd)"
toolchain="${RIFT_TOOLCHAIN:-1.99.1}"
keychain="$HOME/Library/Keychains/rift-local.keychain-db"
identity="19717AD2D9764B862B4F6F0C150D32DD75029358"

(cd "$src" && cargo "+$toolchain" build --release --locked --package rift-wm --bin rift)

app="$(brew --prefix)/opt/rift/Rift.app"
stage="$(mktemp -d)/Rift.app"
cp -R "$app" "$stage"
cp "$src/target/release/rift" "$stage/Contents/MacOS/rift"
strip -x "$stage/Contents/MacOS/rift"
security unlock-keychain -p "$(security find-generic-password -s rift-local-keychain -a "$USER" -w)" "$keychain"
codesign --force --keychain "$keychain" --sign "$identity" --identifier git.acsandmann.rift "$stage"

# opt/ is a symlink into the Cellar; replace the real bundle.
target="$(cd "$app" && pwd -P)"
rm -rf "$target"
mv "$stage" "$target"
brew services restart acsandmann/tap/rift
"$target/Contents/MacOS/rift" --version
