import 'dart:typed_data';

void downloadImage(Uint8List bytes, String filename) {
  // Stub for non-web platforms. Should never be called since kIsWeb guards it.
  throw UnsupportedError('downloadImage is only supported on the web.');
}
