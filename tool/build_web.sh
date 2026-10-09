#!/usr/bin/env bash
# Builds the FOCR web app and packages it for deployment.
#
#   ./tool/build_web.sh                      # app served at the domain root (/)
#   BASE_HREF=/focr/ ./tool/build_web.sh     # app served under a sub-path
#
# Output: dist/FOCR-web-<version>.tar.gz (+ .zip, .sha256). Each archive contains public/ (web
# root), nginx/focr.conf, Dockerfile and PANDUAN-DEPLOY.md (docs/deploy-web.id.md).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BASE_HREF="${BASE_HREF:-/}"
VERSION="$(awk '/^version:/ {print $2}' pubspec.yaml)"          # e.g. 0.1.0+4
NAME="FOCR-web-${VERSION/+/-build}"                              # e.g. FOCR-web-0.1.0-build4
BUILD_ID="${VERSION}-$(date -u +%Y%m%d%H%M%S)"

[[ -s web/tesseract/lang/eng.traineddata.gz ]] || ./tool/fetch_tesseract_assets.sh

echo "Building $NAME (base href: $BASE_HREF)"
flutter build web --release --no-web-resources-cdn --base-href "$BASE_HREF"

# Unique service-worker cache per build: clients drop the old cache after a deploy.
sed -i.bak "s/__FOCR_BUILD__/${BUILD_ID}/" build/web/sw.js && rm build/web/sw.js.bak
grep -q "focr-${BUILD_ID}" build/web/sw.js

# Debug symbols are not needed at runtime.
find build/web -name '*.symbols' -delete

STAGE="dist/$NAME"
rm -rf "$STAGE" "dist/$NAME.tar.gz" "dist/$NAME.zip"
mkdir -p "$STAGE/nginx"
cp -R build/web "$STAGE/public"
cp deploy/nginx/focr.conf "$STAGE/nginx/focr.conf"
cp deploy/Dockerfile "$STAGE/Dockerfile"
cp docs/deploy-web.id.md "$STAGE/PANDUAN-DEPLOY.md"
printf 'version=%s\nbuild_id=%s\nbase_href=%s\n' "$VERSION" "$BUILD_ID" "$BASE_HREF" > "$STAGE/BUILD_INFO.txt"

tar -czf "dist/$NAME.tar.gz" -C dist "$NAME"
(cd dist && zip -qr "$NAME.zip" "$NAME")
(cd dist && shasum -a 256 "$NAME.tar.gz" "$NAME.zip" > "$NAME.sha256")
rm -rf "$STAGE"

echo "Done:"
ls -lh "dist/$NAME".*
