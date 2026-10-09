import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Image preprocessing for OCR (contracts/interfaces.md).
abstract interface class ImageOps {
  /// Decode, apply EXIF orientation, downscale so the longest side ≤ [maxSide], encode JPEG.
  /// Throws [FormatException] if the bytes are not a decodable image.
  Future<Uint8List> normalize(Uint8List input, {int maxSide = 2000});

  /// Rotate an encoded image clockwise by 90, 180 or 270 degrees and downscale to ≤ [maxSide].
  Future<Uint8List> rotate(Uint8List jpeg, int degrees, {int maxSide = 2000});
}

/// Pure-Dart implementation on `package:image`. Uses [compute], which runs on a background
/// isolate on mobile and inline on web (no isolates there).
class DartImageOps implements ImageOps {
  const DartImageOps();

  @override
  Future<Uint8List> normalize(Uint8List input, {int maxSide = 2000}) =>
      compute(_normalize, (input, maxSide));

  @override
  Future<Uint8List> rotate(Uint8List jpeg, int degrees, {int maxSide = 2000}) {
    assert(const {0, 90, 180, 270}.contains(degrees));
    return compute(_rotate, (jpeg, degrees, maxSide));
  }
}

img.Image _decode(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) throw const FormatException('Unsupported or corrupt image');
  return image;
}

img.Image _fit(img.Image image, int maxSide) {
  final longest = image.width > image.height ? image.width : image.height;
  if (longest <= maxSide) return image;
  return image.width >= image.height
      ? img.copyResize(image, width: maxSide, interpolation: img.Interpolation.average)
      : img.copyResize(image, height: maxSide, interpolation: img.Interpolation.average);
}

Uint8List _normalize((Uint8List, int) args) {
  final (bytes, maxSide) = args;
  final image = _fit(img.bakeOrientation(_decode(bytes)), maxSide);
  return img.encodeJpg(image, quality: 90);
}

Uint8List _rotate((Uint8List, int, int) args) {
  final (bytes, degrees, maxSide) = args;
  var image = _decode(bytes);
  if (degrees != 0) image = img.copyRotate(image, angle: degrees);
  return img.encodeJpg(_fit(image, maxSide), quality: 90);
}
