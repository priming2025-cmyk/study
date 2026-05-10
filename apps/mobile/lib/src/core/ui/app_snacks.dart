import 'package:flutter/material.dart';

/// SnackBar를 한곳에서 쓰면 문구·동작(mounted)을 나중에 바꾸기 쉽습니다.
abstract final class AppSnacks {
  static void show(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// `await` 전에 얻은 [messenger]로 표시 — 비동기 이후 `BuildContext` 린트 회피.
  static void showWithMessenger(ScaffoldMessengerState messenger, String message) {
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  static void error(BuildContext context, Object error) {
    show(context, error.toString());
  }
}
