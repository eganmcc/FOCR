# Data Model: BCA Registration Number Capture

## Value types (pure Dart, `lib/core/extraction/`)

### RegistrationNumber
| Field | Type | Rule |
|---|---|---|
| value | String | matches `^A03(?:\d{13}\|C\d{6})$` |
| format | enum `long` \| `short` | long = 16 chars, short = 10 chars |
| applicationDate | Date? | long only: chars 3–10 as DDMMYYYY; must be a real date, ≤ today, ≥ today − 60 days |
| sequence | String | long: last 5 digits; short: last 6 digits |

The only way to build one is `RegistrationNumber.tryParse(String, {required DateTime today, int windowDays = 60})`,
which returns a `ValidationResult` (valid, or invalid with a reason: `badFormat`, `invalidDate`, `futureDate`, `tooOld`).

### ExtractionResult
Either `Found(number, source: anchor|global, rawCandidate)` or `NotFound(candidatesRejected: List<(raw, reason)>)`.

### ScanResult
| Field | Type |
|---|---|
| extraction | ExtractionResult |
| rotationDegrees | 0 \| 90 \| 180 \| 270 (the orientation that matched, or the last one tried) |
| rawText | String (OCR text of the matching or last pass) |
| elapsed | Duration |
| normalizedImage | bytes (JPEG, EXIF applied, upright according to rotationDegrees, longest side ≤ 1280 px) |

## Persisted entities (sembast, `lib/data/`)

### Capture (`captures` store, key: UUID string)
| Field | Type | Notes |
|---|---|---|
| id | String (UUID v4) | |
| imageJpeg | Blob | the normalized image (≤ 1280 px) |
| rotationDegrees | int | |
| rawText | String | kept on the device only, for troubleshooting (FR-015) |
| createdAt | ISO-8601 String (UTC) | |

### RegistrationRecord (`records` store, key: UUID string)
| Field | Type | Notes |
|---|---|---|
| id | String (UUID v4) | |
| number | String | a validated RegistrationNumber.value |
| format | `long` \| `short` | |
| applicationDate | ISO date String? | long format only |
| captureId | String? | null if entered fully manually without an image |
| entryMethod | `auto` \| `edited` \| `manual` | auto = confirmed unchanged; edited = OCR value changed; manual = no OCR result |
| duplicateOverride | bool | true if the salesperson saved despite a duplicate warning |
| syncStatus | `pending` \| `synced` | always `pending` in this feature |
| confirmedAt | ISO-8601 String (UTC) | |
| syncedAt | ISO-8601 String? | set by the future SyncService |

Index/query: `findByNumber(number)` filters on `number` for the duplicate check (FR-012).
The list is sorted by `confirmedAt` descending (FR-014).

### State transitions
```
(new) --confirm--> pending --SyncService.push ok--> synced
pending --edit (history)--> pending   (number revalidated)
synced: read-only in this feature
```

## Relationships
`RegistrationRecord 0..1 → 1 Capture`. A Capture without a record (abandoned scan) is deleted when the
review screen is dismissed without saving.
