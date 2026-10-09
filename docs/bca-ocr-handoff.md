# Handoff: BCA credit card registration number OCR

## Goal
Salespeople upload one screenshot or photo per BCA credit card application. The app must extract the
**registration number** ("No. registrasi aplikasi Kartu Kredit BCA Anda adalah ...")
quickly and reliably, preferably with on-device OCR.

## Input characteristics (from real samples)
- Usually a **photo of another phone's screen**: glare, moiré, cracked glass, blur, tilt.
- Often **rotated 90°/180°/270°** (3 of 6 samples were sideways).
- Sometimes a real screenshot, or the BCA confirmation email ("Pengajuan Anda Telah Terkirim ke BCA").
- The number sits right after the anchor text **"adalah"** on the confirmation page,
  or after **"Nomor Registrasi:"** in the email.

## Registration number formats
| Format | Regex | Structure |
|---|---|---|
| Long (16 chars) | `A03\d{13}` | `A03` + date DDMMYYYY + 5-digit sequence |
| Short (10 chars) | `A03C\d{6}` | `A03C` + 6 digits (no date) |

Combined: `\bA03(?:\d{13}|C\d{6})\b`

## Test samples (expected outputs)
| Source | Expected |
|---|---|
| Email, 22 Sep 2026 | A032209202601890 |
| Confirmation page, upright | A030510202600701 |
| Rotated 90° | A030210202606071 |
| Rotated, cracked screen | A030310202600958 |
| Rotated, glare | A03C526979 |
| Blurry browser (webform.bca.co.id) | A03C511198 |
| Rotated | A03C509864 |

(Put the original images in `test/fixtures/` and wire them into the tests.)

## Approach
1. **OCR engine (on-device)**
   - Android / Flutter / React Native: Google ML Kit Text Recognition v2 (Latin).
   - iOS: Apple Vision `VNRecognizeTextRequest`.
   - Web-only fallback: Tesseract.js (slower, weaker on screen photos).
2. **Rotation**: run OCR upright. If there is no valid match, retry at 90°, 180° and 270°, and stop at the first valid match.
3. **Extraction**
   - Prefer the text following "adalah" or "Nomor Registrasi".
   - Strip spaces inside the candidate token.
   - In digit positions only, map O→0, I/l→1, S→5, B→8, Z→2. Keep `A` at position 0 and a possible `C` at position 3.
   - Validate against the regex.
4. **Validation**
   - Long format: the embedded DDMMYYYY must be a real date, not in the future, and within roughly the last 60 days.
   - Reject anything that fails the regex; don't guess.
5. **UX**
   - Preferred: **live camera scan**. Run OCR on each frame and auto-lock when the regex matches.
   - Fallback: upload an image.
   - Always show the extracted number in an **editable, pre-filled field** next to the image; the salesperson confirms or corrects it.
   - Flag **duplicates** (the same number already submitted).
6. **Fallback**: if nothing valid is found on-device, send that single image to a cloud OCR or vision model, or ask for manual entry.

## Open question
What is the sales app built with: native Android, Flutter, React Native, or a web form?
This decides which OCR library to integrate.
