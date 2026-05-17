import 'dart:typed_data';

/// 네이티브 빌드용 스텁 (API는 웹 구현과 동일하게 유지).
final class WebSharedCamera {
  WebSharedCamera._();
  static final WebSharedCamera instance = WebSharedCamera._();

  Object? get video => null;
  String? get lastOpenError => null;

  bool get isStreamReady => false;

  void openFromUserGesture() {}

  Future<Object?> acquire() async => null;

  Future<Uint8List?> captureJpeg({
    double maxDim = 480,
    double quality = 0.88,
  }) async =>
      null;

  void release() {}

  void forceRelease() {}
}
