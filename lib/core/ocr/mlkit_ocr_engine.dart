import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

import 'ocr_engine.dart';

OcrEngine createOcrEngine() => MlKitOcrEngine();

/// Google ML Kit Text Recognition v2 (Latin), on-device, for Android and iOS.
class MlKitOcrEngine implements OcrEngine {
  final TextRecognizer _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  int _seq = 0;

  @override
  bool get supportsSparseLayout => false;

  @override
  Future<String> recognize(Uint8List encodedImage, {OcrLayout layout = OcrLayout.block}) async {
    // ML Kit only takes raw camera buffers or files; encoded images go through a temp file.
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/focr_ocr_${pid}_${_seq++}.jpg');
    try {
      await file.writeAsBytes(encodedImage, flush: true);
      final result = await _recognizer.processImage(InputImage.fromFilePath(file.path));
      return result.text;
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  @override
  Future<void> dispose() => _recognizer.close();
}
