# Feature Specification: BCA Registration Number Capture

**Feature Branch**: `001-registration-ocr`

**Created**: 2026-10-09

**Status**: Draft

**Input**: User description: "Salespeople upload one screenshot or photo per BCA credit card application.
The app must extract the registration number ('No. registrasi aplikasi Kartu Kredit BCA Anda adalah ...')
quickly and reliably, preferably on-device, on Android, iOS and Web, with semi-offline capability.
Backend comes later; focus on the OCR functionality." (Source: `docs/bca-ocr-handoff.md`)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Extract the number from an uploaded image (Priority: P1)

A salesperson picks a screenshot or photo of a BCA application confirmation (the confirmation page,
or the "Pengajuan Anda Telah Terkirim ke BCA" email). The app reads the image and shows the
registration number in an editable, pre-filled field next to the image. The salesperson checks it,
corrects it if needed, and confirms.

**Why this priority**: This is the core value: no more retyping 10–16 character codes by hand.
It works on every platform, including Web where live camera scanning is limited.

**Independent Test**: Upload each of the 7 reference samples and check that the pre-filled value
equals the expected number in the table below.

**Acceptance Scenarios**:

1. **Given** an upright confirmation-page screenshot, **When** the salesperson uploads it, **Then** the
   field is pre-filled with the registration number (for example `A030510202600701`).
2. **Given** the BCA confirmation email, **When** it is uploaded, **Then** the number after "Nomor
   Registrasi:" is pre-filled (for example `A032209202601890`).
3. **Given** an image containing no valid registration number, **When** it is uploaded, **Then** the
   field is left empty, the salesperson is told no number was found, and they can type it manually.
4. **Given** a pre-filled number, **When** the salesperson edits it to a value that does not match a
   valid format, **Then** confirmation is blocked and the reason is shown.

---

### User Story 2 - Robust reading of real-world phone photos (Priority: P1)

Most inputs are photos of another phone's screen, taken sideways or upside down, with glare, moiré,
cracked glass or blur. The app still finds the number without the salesperson rotating or cropping
anything.

**Why this priority**: 3 of the 6 real photo samples are rotated, and most are photos of a screen.
Without this, Story 1 fails on the majority of real inputs.

**Independent Test**: Run all 7 reference samples (below) through extraction; all must return their
expected value with no manual rotation.

**Acceptance Scenarios**:

1. **Given** a photo rotated 90°, 180° or 270°, **When** it is processed, **Then** the correct number
   is extracted.
2. **Given** OCR output where digits are misread as look-alike letters (O/0, I/l/1, S/5, B/8, Z/2),
   or the number is split by spaces, **When** it is processed, **Then** the normalized number is
   proposed, and only if it passes validation.
3. **Given** a long-format number whose embedded date is invalid, in the future, or older than the
   recency window, **When** it is processed, **Then** it is rejected and not proposed.

Reference samples (originals go in `test/fixtures/`):

| Source | Expected |
|---|---|
| Email, 22 Sep 2026 | A032209202601890 |
| Confirmation page, upright | A030510202600701 |
| Rotated 90° | A030210202606071 |
| Rotated, cracked screen | A030310202600958 |
| Rotated, glare | A03C526979 |
| Blurry browser (webform.bca.co.id) | A03C511198 |
| Rotated | A03C509864 |

---

### User Story 3 - Save offline and catch duplicates (Priority: P2)

After confirming, the salesperson saves the record. Saving works with no connection. The record is
kept on the device and marked as pending sync. If the same registration number was already saved on
this device, the app warns the salesperson before saving again.

**Why this priority**: Field work often has poor connectivity, and duplicate submissions cause
commission and audit problems. Sync itself waits for the future backend.

**Independent Test**: With the device offline, confirm and save two different numbers, then try to
save one of them again. The records persist after the app restarts, and the duplicate is flagged.

**Acceptance Scenarios**:

1. **Given** no network connection, **When** the salesperson saves a confirmed number, **Then** it is
   stored on the device with status "pending".
2. **Given** a number already saved on this device, **When** the same number is confirmed again,
   **Then** a duplicate warning names the earlier save date. Saving again requires an explicit
   override.
3. **Given** saved records, **When** the app is closed and reopened (including the Web version, also
   offline), **Then** all records are still there.

---

### User Story 4 - Live camera scan with auto-lock (Priority: P2)

Instead of taking a photo first, the salesperson points the camera at the other phone's screen. The
app reads continuously and locks automatically as soon as a valid number is found. It then shows the
same editable confirmation screen as Story 1.

**Why this priority**: This is the fastest path on mobile and avoids blurry stills. It isn't required
for an MVP, because upload already covers the need.

**Independent Test**: Display a reference sample on a second screen, start the scan, and check that
it locks onto the expected number in under 3 seconds without the salesperson pressing anything.

**Acceptance Scenarios**:

1. **Given** camera permission is granted, **When** a valid number comes into view, **Then** the scan
   locks, captures the frame and opens the confirmation screen with the number pre-filled.
2. **Given** camera permission is denied or no camera exists, **When** the salesperson opens the
   scanner, **Then** they are offered image upload instead.

---

### User Story 5 - History of captured numbers (Priority: P3)

The salesperson can see a list of saved records (number, image thumbnail, date, and pending/synced
status) and correct a pending record.

**Why this priority**: Useful for checking work and finding duplicates by eye, but not essential to
capture.

**Independent Test**: Save three records, open history, and check that they appear newest first with
status "pending".

**Acceptance Scenarios**:

1. **Given** saved records, **When** history is opened, **Then** they are listed newest first, with
   number, thumbnail, capture time and status.

---

### Edge Cases

- The image contains more than one candidate (for example a reference number and the registration
  number): the candidate following "adalah" or "Nomor Registrasi" wins. Otherwise the first valid one
  wins, and the salesperson still confirms.
- A short-format number (`A03C` + 6 digits) has no date, so the date checks don't apply to it.
- The image is too dark or too small to read: the result is "not found", with a hint to retake the
  photo.
- An unsupported file type, or a very large file (over 20 MB): it is rejected with a clear message.
- The salesperson uploads the same image twice: this is caught by the duplicate check (Story 3).
- The device clock is wrong: the recency check uses the device date. A false rejection can still be
  fixed with manual entry.
- An image with no network and no on-device result: manual entry is offered. A cloud fallback is not
  available until the backend exists.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST accept one image per application from the device gallery or file system
  (common formats: JPEG, PNG, HEIC where the platform supports it, WebP).
- **FR-002**: The system MUST recognize text in the image on the device, with no network connection
  required, on Android, iOS and Web.
- **FR-003**: If no valid number is found in the image's original orientation, the system MUST retry
  at 90°, 180° and 270°, and stop at the first valid result.
- **FR-004**: The system MUST prefer the candidate that immediately follows the anchor text "adalah"
  or "Nomor Registrasi" (case-insensitive).
- **FR-005**: The system MUST remove whitespace inside a candidate. In digit positions only, it MUST
  map O→0, I/l→1, S→5, B→8, Z→2, while keeping `A` at position 1 and an optional `C` at position 4.
- **FR-006**: The system MUST accept only values matching `A03` + 13 digits (long) or `A03C` + 6
  digits (short).
- **FR-007**: For the long format, the system MUST reject values whose embedded DDMMYYYY date is not a
  real date, is later than today, or is more than 60 days before today.
- **FR-008**: The system MUST NOT propose a value that fails FR-006 or FR-007. It MUST show
  "not found" and allow manual entry instead.
- **FR-009**: The system MUST show the source image next to an editable field pre-filled with the
  extracted value, and MUST require explicit confirmation before saving.
- **FR-010**: The system MUST apply the FR-006/FR-007 validation to manually entered or edited values
  before allowing confirmation.
- **FR-011**: The system MUST store confirmed records on the device, persistently and offline, with
  status "pending" until a future sync marks them "synced".
- **FR-012**: The system MUST warn when a confirmed number already exists in the on-device records,
  and require an explicit override to save it again.
- **FR-013**: On devices with a camera, the system SHOULD provide a live scan mode that auto-locks on
  the first valid number.
- **FR-014**: The system MUST list saved records, newest first, with number, thumbnail, capture time
  and status.
- **FR-015**: Application images MUST NOT leave the device in this feature. They MUST be kept only in
  the app's local storage, together with their record.
- **FR-016**: The system MUST provide an extension point for a future network fallback (cloud OCR) and
  a future backend sync. In this feature both are inactive, with no visible broken controls.

### Key Entities

- **Capture**: one processed image. Holds the source image, the detected orientation, the raw
  recognized text (kept on the device for troubleshooting), the extracted candidate (or none), and the
  processing time.
- **Registration Record**: a confirmed registration number. Holds the number, its format (long or
  short), the embedded application date (long format only), a link to its Capture, whether it was
  auto-extracted or manually entered/edited, the confirmation time, sync status (pending/synced), and
  whether it was saved with a duplicate override.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All 7 reference samples return their expected number with no manual correction.
- **SC-002**: Across a field test of at least 50 real captures, at least 90% are pre-filled correctly,
  and 0 are pre-filled with a wrong value that passes validation.
- **SC-003**: For an upright image, the number appears within 2 seconds on a mid-range phone. In the
  worst case (all orientations tried), it appears within 5 seconds.
- **SC-004**: A salesperson can go from opening the app to a saved record in under 15 seconds.
- **SC-005**: With no network, every capture → confirm → save step works on Android, iOS and Web
  (after the Web app has been opened online at least once).
- **SC-006**: 100% of repeat saves of an already-saved number trigger the duplicate warning.

## Assumptions

- One salesperson per device. There are no accounts or login in this feature; identity comes with
  the backend.
- Duplicate detection is per device until the backend exists.
- The 60-day recency window and the 20 MB file limit are sensible defaults and can be configured
  later.
- The Web version must be loaded online once to cache what it needs for offline use. Web OCR accuracy
  may be lower than on mobile, and manual entry covers the gap.
- The future backend will define sync, cloud OCR fallback, and server-side duplicate checks. Here
  they are only extension points.
- The original sample images will be provided by the project owner and placed in `test/fixtures/`.
