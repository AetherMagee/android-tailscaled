#!/usr/bin/env bash
# Builds the module zip: upstream tailscale + patches/ -> dist/android-tailscaled-<version>.zip
#
# Usage: ./build.sh [upstream-tag]   (default: latest upstream release)
# Env:   SKIP_TESTS=1 to skip the patched packages' tests
set -euo pipefail

ROOT=$(cd "$(dirname "$0")" && pwd)
WORK="$ROOT/.work"
DIST="$ROOT/dist"
SRC="$WORK/tailscale"

TAG="${1:-$(curl -fsSL https://api.github.com/repos/tailscale/tailscale/releases/latest | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p')}"
REV=$(cat "$ROOT/REVISION")
VERSION="${TAG}-r${REV}"
# 1.104.1 r2 -> 110400102
IFS=. read -r MAJ MIN PAT <<<"${TAG#v}"
VERSION_CODE=$(( (MAJ * 1000000 + MIN * 1000 + PAT) * 100 + REV ))

# Features that make no sense on a phone; keeps the binary ~30% smaller.
OMIT=portlist,aws,kube,bird,synology,systray,tpm,networkmanager,resolved,sdnotify,flashappliance,desktop_sessions,serviceclientprefs,clientupdate,linuxdnsfight,cloud,tap,completion_scripts
# Tests with fwmark values baked into nftables netlink bytes; we run in iptables mode.
TEST_SKIP='TestAddSetSubnetRouteMarkRule|TestAddMatchSubnetRouteMarkRule|TestMakeConnmark(Restore|Save)Exprs'
TEST_PKGS="./version/distro/ ./paths/ ./net/dns/ ./net/netns/ ./wgengine/router/osrouter/ ./util/linuxfw/"

echo "==> tailscale $TAG, module $VERSION ($VERSION_CODE)"

rm -rf "$SRC" && mkdir -p "$WORK" "$DIST"
git -c advice.detachedHead=false clone -q --depth 1 --branch "$TAG" https://github.com/tailscale/tailscale "$SRC"

echo "==> applying patches"
git -C "$SRC" -c user.name=build -c user.email=build@localhost am -q "$ROOT"/patches/*.patch

cd "$SRC"
if [ -z "${SKIP_TESTS:-}" ]; then
	echo "==> testing patched packages"
	# shellcheck disable=SC2086
	go test -skip "$TEST_SKIP" $TEST_PKGS
fi

echo "==> building linux/arm64"
TAGS="ts_include_cli,$(go run ./cmd/featuretags --remove "$OMIT")" \
	CGO_ENABLED=0 GOOS=linux GOARCH=arm64 \
	./build_dist.sh --strip -trimpath -o "$WORK/tailscaled" ./cmd/tailscaled

echo "==> packaging"
STAGE="$WORK/module"
rm -rf "$STAGE" && cp -r "$ROOT/module" "$STAGE"
mkdir -p "$STAGE/system/bin"
cp "$WORK/tailscaled" "$STAGE/system/bin/tailscaled" # customize.sh adds the tailscale symlink
sed -i -e "s/^version=.*/version=$VERSION/" -e "s/^versionCode=.*/versionCode=$VERSION_CODE/" "$STAGE/module.prop"

ZIP="$DIST/android-tailscaled-$VERSION.zip"
rm -f "$ZIP"
(cd "$STAGE" && zip -qr9 "$ZIP" .)

# Consumed by CI.
cat >"$DIST/build.env" <<EOF
TAG=$TAG
VERSION=$VERSION
VERSION_CODE=$VERSION_CODE
ZIP=$ZIP
EOF
echo "==> $ZIP"
