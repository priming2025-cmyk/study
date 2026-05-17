/// iOS 시간 축 환각 차단기 (순수 Dart).
///
/// face_detection_tflite는 iOS의 빈/잘못된 프레임에서도 거의 같은 mesh를
/// 반복적으로 반환해 `facePresent`가 true로 굳어지는 문제가 있습니다.
/// 진짜 얼굴은 호흡·미세 떨림으로 bbox 중심이 자연스럽게 흔들립니다.
/// - 최근 N프레임 bbox 중심 폭(spread)이 매우 작음 → 환각으로 간주, 거부
/// - spread가 프레임의 70% 이상 → 잡음, 거부
/// - EAR 양쪽이 5e-4 이내로 동일하면 동결로 간주, 즉시 거부
class IosTemporalCoherence {
  static const int _window = 5;
  static const double _frozenSpreadPx = 0.6;
  static const double _eraticSpreadRatio = 0.7;
  static const double _earSameEpsilon = 0.0008;
  static const int _earSameMax = 2;

  final List<_BboxCenter> _centers = [];
  double? _lastEarL;
  double? _lastEarR;
  int _earSameStreak = 0;

  /// 환각으로 판단되면 false 반환. 새 샘플은 자동으로 윈도우에 누적.
  bool consumeAndIsPlausible({
    required double bboxLeft,
    required double bboxTop,
    required double bboxRight,
    required double bboxBottom,
    required double earL,
    required double earR,
    required double frameWidth,
    required double frameHeight,
  }) {
    final cx = (bboxLeft + bboxRight) / 2.0;
    final cy = (bboxTop + bboxBottom) / 2.0;
    _centers.add(_BboxCenter(cx, cy));
    if (_centers.length > _window) {
      _centers.removeAt(0);
    }

    final hasPrevEar = _lastEarL != null && _lastEarR != null;
    final earSame = hasPrevEar &&
        (_lastEarL! - earL).abs() < _earSameEpsilon &&
        (_lastEarR! - earR).abs() < _earSameEpsilon;
    if (earSame) {
      _earSameStreak++;
    } else {
      _earSameStreak = 0;
    }
    _lastEarL = earL;
    _lastEarR = earR;

    if (_earSameStreak > _earSameMax) {
      return false;
    }

    if (_centers.length < 3) return true;

    var minX = double.infinity;
    var maxX = -double.infinity;
    var minY = double.infinity;
    var maxY = -double.infinity;
    for (final c in _centers) {
      if (c.x < minX) minX = c.x;
      if (c.x > maxX) maxX = c.x;
      if (c.y < minY) minY = c.y;
      if (c.y > maxY) maxY = c.y;
    }
    final spreadX = maxX - minX;
    final spreadY = maxY - minY;

    if (spreadX < _frozenSpreadPx && spreadY < _frozenSpreadPx) {
      return false;
    }
    if (frameWidth > 0 && frameHeight > 0) {
      if (spreadX > frameWidth * _eraticSpreadRatio ||
          spreadY > frameHeight * _eraticSpreadRatio) {
        return false;
      }
    }
    return true;
  }

  void reset() {
    _centers.clear();
    _lastEarL = null;
    _lastEarR = null;
    _earSameStreak = 0;
  }
}

class _BboxCenter {
  final double x;
  final double y;
  const _BboxCenter(this.x, this.y);
}
