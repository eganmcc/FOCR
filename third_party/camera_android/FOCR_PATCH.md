# Vendored camera_android 0.10.12 (FOCR patch)

Upstream: https://pub.dev/packages/camera_android (version 0.10.12, unmodified except below).
`example/` and the unit tests were removed.

## Patch
`android/src/main/java/io/flutter/plugins/camera/Camera.java`, `closeCaptureSession()`:
reads `captureSession` into a local before closing it.

**Why:** `CameraDevice.StateCallback.onClosed` calls `closeCaptureSession()` on the camera background
thread, while `close()` → `stopAndReleaseCamera()` on the main thread sets `captureSession = null`.
The check-then-use on the field raced, crashing with
`NullPointerException: ... CameraCaptureSession.close() on a null object reference` when the scan
screen disposed the camera. Seen twice on a Xiaomi 24115RA8EG on 2026-10-09; 0.10.12+1 is still affected.

Remove this override (pubspec `dependency_overrides`) once upstream fixes it.

## Patch 2: capture steps racing with close()
`runPrecaptureSequence()`, `captureStillPicture()`, `lockAutoFocus()` and `unlockAutoFocus()` run
from capture callbacks on the camera background thread. If the camera is closed mid-sequence
(leaving the scan screen while a frame is being taken), `captureSession.capture(...)` throws
`IllegalStateException: CameraDevice was already closed` (or NPE on a nulled session). Upstream only
catches `CameraAccessException`, so the app crashed. These four now also catch
`IllegalStateException | NullPointerException`: they log and stop, and the still capture reports an
error to Dart. Reproduced on an API 34 emulator by opening and closing the scan screen 15×.
