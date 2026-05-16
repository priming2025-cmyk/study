import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../session/infra/attention_camera_service.dart';

/// 스터디방 본인 실시간 프리뷰용 [CameraPreview] 박스.
class StudyRoomSelfCameraPreviewBox extends StatelessWidget {
  final double width;
  final double height;

  const StudyRoomSelfCameraPreviewBox({
    super.key,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final cam = AttentionCameraService.instance.controller;
    if (cam == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white54),
      );
    }
    return ListenableBuilder(
      listenable: cam,
      builder: (context, _) {
        if (!cam.value.isInitialized) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white54),
          );
        }
        var ar = cam.value.aspectRatio;
        if (!ar.isFinite || ar <= 1e-6) ar = 9 / 16;
        return FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          alignment: Alignment.center,
          child: SizedBox(
            width: width,
            height: width / ar,
            child: CameraPreview(cam),
          ),
        );
      },
    );
  }
}
