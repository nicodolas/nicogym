#!/usr/bin/env bash
set -euo pipefail

flutter_root="/opt/buildhome/flutter-${FLUTTER_VERSION}"

if [[ ! -x "${flutter_root}/bin/flutter" ]]; then
  git clone \
    --branch "${FLUTTER_VERSION}" \
    --depth 1 \
    https://github.com/flutter/flutter.git \
    "${flutter_root}"
fi

"${flutter_root}/bin/flutter" config --enable-web
"${flutter_root}/bin/flutter" pub get
"${flutter_root}/bin/flutter" build web \
  --release \
  --dart-define="API_BASE_URL=${API_BASE_URL:?API_BASE_URL is required}" \
  --dart-define="APK_DOWNLOAD_URL=${APK_DOWNLOAD_URL:?APK_DOWNLOAD_URL is required}"
