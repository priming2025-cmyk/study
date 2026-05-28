import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 열품타 스타일에 가까운 “앱 이탈 방지”의 현실적인 구현(안드로이드 한정):
/// - startLockTask(): 화면 고정(핀/키오스크) 시도
/// - stopLockTask(): 해제
///
/// iOS는 Guided Access가 OS 기능이라 앱에서 강제로 켤 수 없고,
/// Web도 브라우저/OS 네비게이션을 강제로 막을 수 없습니다.
abstract final class KioskLock {
  static const MethodChannel _ch = MethodChannel('setudy/kiosk');

  static Future<void> enableIfPossible() async {
    if (kIsWeb) return;
    try {
      await _ch.invokeMethod<void>('startLockTask');
    } catch (_) {
      // 기기/정책에 따라 실패 가능. UX는 PopScope/다이얼로그로 보조.
    }
  }

  static Future<void> disableIfPossible() async {
    if (kIsWeb) return;
    try {
      await _ch.invokeMethod<void>('stopLockTask');
    } catch (_) {}
  }
}

