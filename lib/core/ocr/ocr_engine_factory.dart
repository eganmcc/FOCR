// Selects the platform OCR engine at compile time (constitution IV).
export 'ocr_engine_factory_stub.dart'
    if (dart.library.io) 'mlkit_ocr_engine.dart'
    if (dart.library.js_interop) 'tesseract_web_ocr_engine.dart';
