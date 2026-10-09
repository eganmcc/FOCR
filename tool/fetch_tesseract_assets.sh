#!/usr/bin/env bash
# Downloads pinned Tesseract.js assets into web/tesseract/ so the web build runs OCR fully offline
# (no CDN at runtime; see specs/001-registration-ocr/research.md R2).
set -euo pipefail

TESSERACT_JS=7.0.0
TESSERACT_CORE=7.0.0
ENG_DATA=1.0.0

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/web/tesseract"
CDN="https://cdn.jsdelivr.net/npm"

mkdir -p "$OUT/core" "$OUT/lang"

fetch() {
  local url="$1" dest="$2"
  if [[ -s "$dest" ]]; then echo "skip  $dest"; return; fi
  echo "fetch $url"
  curl -fsSL "$url" -o "$dest.part" && mv "$dest.part" "$dest"
}

fetch "$CDN/tesseract.js@$TESSERACT_JS/dist/tesseract.min.js" "$OUT/tesseract.min.js"
fetch "$CDN/tesseract.js@$TESSERACT_JS/dist/worker.min.js" "$OUT/worker.min.js"

# LSTM-only builds (we use OEM 1); tesseract.js picks the variant from browser SIMD support.
for variant in lstm simd-lstm relaxedsimd-lstm; do
  fetch "$CDN/tesseract.js-core@$TESSERACT_CORE/tesseract-core-$variant.wasm.js" "$OUT/core/tesseract-core-$variant.wasm.js"
done

fetch "$CDN/@tesseract.js-data/eng@$ENG_DATA/4.0.0_best_int/eng.traineddata.gz" "$OUT/lang/eng.traineddata.gz"

echo "Tesseract assets ready in $OUT"
