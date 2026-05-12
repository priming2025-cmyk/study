import 'package:flutter/material.dart';

import '../domain/attention_signals.dart';

/// 네이티브(iOS·Android 등): 웹 전용 위젯이 아니므로 빈 박스(사용하지 않음).
class SessionSelfCameraSurface extends StatelessWidget {
  final double width;
  final double height;
  final bool Function()? appInForeground;
  final void Function(AttentionSignals)? onAttentionSignals;

  const SessionSelfCameraSurface({
    super.key,
    required this.width,
    required this.height,
    this.appInForeground,
    this.onAttentionSignals,
  });

  @override
  Widget build(BuildContext context) => SizedBox(width: width, height: height);
}
