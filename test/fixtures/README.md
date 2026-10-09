# Test fixtures

## images/
Put the original sample images here, using these exact filenames. Any extension from
jpg/jpeg/png works; the integration test matches files by name stem.
`integration_test/ocr_samples_test.dart` reads them.

| File stem | Source | Expected |
|---|---|---|
| `email` | BCA email, 22 Sep 2026 | A032209202601890 |
| `upright` | Confirmation page, upright | A030510202600701 |
| `rotated_90` | Rotated 90° | A030210202606071 |
| `rotated_cracked` | Rotated, cracked screen | A030310202600958 |
| `rotated_glare` | Rotated, glare | A03C526979 |
| `blurry_browser` | Blurry browser (webform.bca.co.id) | A03C511198 |
| `rotated` | Rotated | A03C509864 |

The long-format numbers embed dates from Sep–Oct 2026, so tests fix the clock at **2026-10-09**.

## ocr_text/
Plain-text OCR outputs (clean and noisy variants) for each sample, used by the pure-Dart extractor
tests. The first line of each file is `# expected: <number>` or `# expected: none`.
