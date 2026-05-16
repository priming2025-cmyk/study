import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// 앱 전체에서 **전면 카메라는 한 센서만** 점유 (공부 세션 ↔ 셋터디방 경합 방지).
class CameraExclusiveGate {
  CameraExclusiveGate._();

  static Object? _holder;
  static Future<void> Function()? _releaseHeld;

  static Future<void> claim({
    required Object holder,
    required Future<void> Function() release,
  }) async {
    if (_holder != null && _holder != holder) {
      final prev = _releaseHeld;
      _releaseHeld = null;
      _holder = null;
      if (prev != null) {
        try {
          await prev();
        } catch (e) {
          debugPrint('CameraExclusiveGate: 이전 점유 해제 실패 → $e');
        }
        if (!kIsWeb && Platform.isIOS) {
          await Future<void>.delayed(const Duration(milliseconds: 400));
        }
      }
    }
    _holder = holder;
    _releaseHeld = release;
  }

  static Future<void> release(Object holder) async {
    if (_holder != holder) return;
    _holder = null;
    final fn = _releaseHeld;
    _releaseHeld = null;
    if (fn != null) {
      try {
        await fn();
      } catch (e) {
        debugPrint('CameraExclusiveGate: release 실패 → $e');
      }
    }
    if (!kIsWeb && Platform.isIOS) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
  }
}
