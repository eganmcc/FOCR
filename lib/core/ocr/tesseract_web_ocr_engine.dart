import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'ocr_engine.dart';

OcrEngine createOcrEngine() => TesseractWebOcrEngine();

@JS('Tesseract')
external _Tesseract? get _tesseractGlobal;

extension type _Tesseract._(JSObject _) implements JSObject {
  external JSPromise<_Worker> createWorker(JSString langs, JSNumber oem, JSObject options);
}

extension type _Worker._(JSObject _) implements JSObject {
  external JSPromise<JSAny?> setParameters(JSObject params);
  external JSPromise<_Result> recognize(JSAny image);
  external JSPromise<JSAny?> terminate();
}

extension type _Result._(JSObject _) implements JSObject {
  external _Data get data;
}

extension type _Data._(JSObject _) implements JSObject {
  external String get text;
}

/// Tesseract.js 7 running in a Web Worker, with every asset self-hosted under `web/tesseract/`
/// so OCR works offline (research R2). A single worker is created lazily and reused.
class TesseractWebOcrEngine implements OcrEngine {
  Future<_Worker>? _worker;
  OcrLayout? _currentLayout;

  @override
  bool get supportsSparseLayout => true;

  Future<_Worker> _getWorker() => _worker ??= _createWorker();

  Future<_Worker> _createWorker() async {
    final tesseract = _tesseractGlobal;
    if (tesseract == null) {
      throw StateError('Tesseract.js not loaded; check <script src="tesseract/tesseract.min.js"> in index.html');
    }
    // The worker is started from a blob URL, so asset paths must be absolute.
    String abs(String path) => Uri.parse(web.document.baseURI).resolve(path).toString();
    final options = {
      'workerPath': abs('tesseract/worker.min.js'),
      'corePath': abs('tesseract/core/'),
      'langPath': abs('tesseract/lang'),
      'gzip': true,
    }.jsify()! as JSObject;
    // OEM 1 = LSTM only, matching the *-lstm core builds we ship.
    return tesseract.createWorker('eng'.toJS, 1.toJS, options).toDart;
  }

  @override
  Future<String> recognize(Uint8List encodedImage, {OcrLayout layout = OcrLayout.block}) async {
    final worker = await _getWorker();
    if (_currentLayout != layout) {
      final psm = layout == OcrLayout.sparse ? '11' : '6';
      await worker.setParameters({'tessedit_pageseg_mode': psm}.jsify()! as JSObject).toDart;
      _currentLayout = layout;
    }
    final blob = web.Blob([encodedImage.toJS].toJS, web.BlobPropertyBag(type: 'image/jpeg'));
    final result = await worker.recognize(blob).toDart;
    return result.data.text;
  }

  @override
  Future<void> dispose() async {
    final worker = _worker;
    _worker = null;
    if (worker != null) await (await worker).terminate().toDart;
  }
}
