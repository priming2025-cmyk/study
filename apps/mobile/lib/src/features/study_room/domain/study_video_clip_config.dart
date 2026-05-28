/// 셋터디 2초 영상 — 메신저형(카카오톡) 압축 목표.
///
/// 2.5초 · 480p급 · H.264 · 무음 · ~400–600 kbps → 클립당 약 120–200 KB.
abstract final class StudyVideoClipConfig {
  static const recordDuration = Duration(milliseconds: 2500);
  static const slotDurationMs = 2500;
  static const maxUploadBytes = 512 * 1024;
  static const posterMaxDim = 360;
  static const posterJpegQuality = 72;

  /// 웹 MediaRecorder 목표 비트레이트 (bps)
  static const webVideoBitsPerSecond = 480000;
}
