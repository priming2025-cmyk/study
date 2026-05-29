import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../domain/study_room_models.dart';

/// 멤버 카드·뷰어용 공개 미디어 (캡쳐 사진 / 2초 영상 / 휴식 프로필).
class StudyRoomMemberMedia extends StatefulWidget {
  final StudyRoomMember member;
  final String displayLabel;
  final BoxFit fit;

  const StudyRoomMemberMedia({
    super.key,
    required this.member,
    required this.displayLabel,
    this.fit = BoxFit.cover,
  });

  @override
  State<StudyRoomMemberMedia> createState() => _StudyRoomMemberMediaState();
}

class _StudyRoomMemberMediaState extends State<StudyRoomMemberMedia> {
  VideoPlayerController? _video;
  String? _loadedUrl;

  StudyRoomMember get member => widget.member;

  bool get _isVideoMode => member.publicViewerMode == 'video';

  String? get _videoUrl {
    final clip = member.latestClipUrl?.trim();
    if (clip != null && clip.isNotEmpty) return clip;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _syncVideo();
  }

  @override
  void didUpdateWidget(covariant StudyRoomMemberMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.member.latestClipUrl != member.latestClipUrl ||
        oldWidget.member.publicViewerMode != member.publicViewerMode) {
      _syncVideo();
    }
  }

  Future<void> _syncVideo() async {
    final url = _isVideoMode ? _videoUrl : null;
    if (url == null) {
      await _disposeVideo();
      if (mounted) setState(() {});
      return;
    }
    if (_loadedUrl == url && _video != null) return;

    await _disposeVideo();
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _video = controller;
    _loadedUrl = url;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();
    } catch (_) {
      await _disposeVideo();
    }
    if (mounted) setState(() {});
  }

  Future<void> _disposeVideo() async {
    final v = _video;
    _video = null;
    _loadedUrl = null;
    if (v != null) {
      await v.dispose();
    }
  }

  @override
  void dispose() {
    unawaited(_disposeVideo());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (member.publicViewerMode == 'rest') {
      return StudyRoomMemberProfilePlaceholder(
        cs: cs,
        label: widget.displayLabel,
      );
    }

    if (_isVideoMode) {
      final controller = _video;
      if (_videoUrl != null &&
          controller != null &&
          controller.value.isInitialized) {
        return FittedBox(
          fit: widget.fit,
          clipBehavior: Clip.hardEdge,
          alignment: Alignment.center,
          child: SizedBox(
            width: controller.value.size.width,
            height: controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        );
      }
      if (_videoUrl != null) {
        final poster = member.snapshotUrl;
        if (poster != null && poster.isNotEmpty) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                poster,
                fit: widget.fit,
                errorBuilder: (_, __, ___) =>
                    StudyRoomMemberVideoPlaceholder(cs: cs),
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : const StudyRoomMemberVideoPlaceholder(),
              ),
              const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ],
          );
        }
      }
      return StudyRoomMemberVideoPlaceholder(cs: cs);
    }

    final snapshotUrl = member.snapshotUrl;
    if (snapshotUrl != null && snapshotUrl.isNotEmpty) {
      return Image.network(
        snapshotUrl,
        fit: widget.fit,
        errorBuilder: (_, __, ___) => StudyRoomMemberMediaPlaceholder(cs: cs),
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : StudyRoomMemberMediaPlaceholder(cs: cs),
      );
    }

    return StudyRoomMemberMediaPlaceholder(cs: cs);
  }
}

class StudyRoomMemberMediaPlaceholder extends StatelessWidget {
  final ColorScheme cs;

  const StudyRoomMemberMediaPlaceholder({super.key, required this.cs});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: cs.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.photo_camera_outlined,
          size: 48,
          color: cs.onSurfaceVariant.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

class StudyRoomMemberVideoPlaceholder extends StatelessWidget {
  final ColorScheme? cs;

  const StudyRoomMemberVideoPlaceholder({super.key, this.cs});

  @override
  Widget build(BuildContext context) {
    final scheme = cs ?? Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.videocam_outlined,
          size: 48,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

class StudyRoomMemberProfilePlaceholder extends StatelessWidget {
  final ColorScheme cs;
  final String label;

  const StudyRoomMemberProfilePlaceholder({
    super.key,
    required this.cs,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: cs.surfaceContainerHighest,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: cs.secondaryContainer,
              child: Text(
                label.isNotEmpty ? label[0].toUpperCase() : '?',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: cs.onSecondaryContainer,
                  fontSize: 28,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '휴식 중',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
