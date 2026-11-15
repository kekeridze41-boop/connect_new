
#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-1.0.0}"
PACKAGE="connect"
ARCH="all"

BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

mkdir -p "$BUILD_DIR/DEBIAN"
mkdir -p "$BUILD_DIR/usr/bin"
mkdir -p "$BUILD_DIR/usr/share/connect"

cp connect.sh "$BUILD_DIR/usr/share/connect/connect.sh"
cp setup.sh "$BUILD_DIR/usr/share/connect/setup.sh"

chmod 755 "$BUILD_DIR/usr/share/connect/connect.sh"
chmod 755 "$BUILD_DIR/usr/share/connect/setup.sh"

cat > "$BUILD_DIR/usr/bin/connect" <<'EOF'
#!/usr/bin/env bash
set -e

if [[ "${1:-}" == "--setup" ]]; then
    shift
    exec /usr/share/connect/setup.sh "$@"
fi

exec /usr/bin/expect /usr/share/connect/connect.sh "$@"
EOF

chmod 755 "$BUILD_DIR/usr/bin/connect"

cat > "$BUILD_DIR/DEBIAN/control" <<EOF
Package: $PACKAGE
Version: $VERSION
Section: net
Priority: optional
Architecture: $ARCH
Maintainer: Connect Project
Depends: expect, openssh-client, inetutils-telnet, python3
Description: Network equipment connection and diagnostics utility
 Connect automates connection and diagnostics for OLT devices.
EOF

mkdir -p dist

dpkg-deb --build --root-owner-group \
    "$BUILD_DIR" "dist/${PACKAGE}_${VERSION}_${ARCH}.deb"

echo "Готово: dist/${PACKAGE}_${VERSION}_${ARCH}.deb"
