/// 셀로그 타임랩스 재생 속도 (1초당 표시할 분 단위 사진 수).
enum CelologExportSpeed {
  x2(photosPerSecond: 6, label: 'x2'),
  x5(photosPerSecond: 15, label: 'x5'),
  x10(photosPerSecond: 30, label: 'x10');

  const CelologExportSpeed({
    required this.photosPerSecond,
    required this.label,
  });

  final int photosPerSecond;
  final String label;

  /// 인코더 fps 기준, 분당 1장 사진을 몇 프레임 반복할지.
  int frameRepeatAt({int encoderFps = 30}) =>
      (encoderFps / photosPerSecond).round().clamp(1, encoderFps);
}
