import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// 공부·셋터디 중 디스플레이 슬립 방지 (자리 이탈·집중 배지와 무관하게 유지).
abstract final class ScreenWakeGuard {
  static int _refs = 0;

  static bool get isHeld => _refs > 0;

  static Future<void> acquire() async {
    _refs++;
    if (_refs != 1) return;
    try {
      await WakelockPlus.enable();
    } catch (e) {
      debugPrint('[ScreenWakeGuard] enable failed: $e');
    }
  }

  static Future<void> release() async {
    if (_refs <= 0) return;
    _refs--;
    if (_refs != 0) return;
    try {
      await WakelockPlus.disable();
    } catch (e) {
      debugPrint('[ScreenWakeGuard] disable failed: $e');
    }
  }

  /// 앱 복귀·탭 전환 후에도 슬립 방지가 풀리지 않게 재요청.
  static Future<void> refreshIfHeld() async {
    if (_refs <= 0) return;
    try {
      final on = await WakelockPlus.enabled;
      if (!on) await WakelockPlus.enable();
    } catch (e) {
      debugPrint('[ScreenWakeGuard] refresh failed: $e');
    }
  }
}
