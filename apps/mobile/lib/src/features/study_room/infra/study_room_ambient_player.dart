import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// 스터디방 배경 집중음 (로컬 WAV 루프).
enum StudyRoomAmbientTrack {
  none,
  rain,
  cafe,
  white,
  lofi,
}

extension StudyRoomAmbientTrackX on StudyRoomAmbientTrack {
  String? get assetPath {
    switch (this) {
      case StudyRoomAmbientTrack.none:
        return null;
      case StudyRoomAmbientTrack.rain:
        return 'audio/rain.wav';
      case StudyRoomAmbientTrack.cafe:
        return 'audio/cafe.wav';
      case StudyRoomAmbientTrack.white:
        return 'audio/white.wav';
      case StudyRoomAmbientTrack.lofi:
        return 'audio/lofi.wav';
    }
  }

  String get labelKo {
    switch (this) {
      case StudyRoomAmbientTrack.none:
        return '없음';
      case StudyRoomAmbientTrack.rain:
        return '비 소리';
      case StudyRoomAmbientTrack.cafe:
        return '카페 분위기';
      case StudyRoomAmbientTrack.white:
        return '화이트 노이즈';
      case StudyRoomAmbientTrack.lofi:
        return 'Lo-fi (플레이스홀더)';
    }
  }
}

class StudyRoomAmbientPlayer {
  AudioPlayer? _player;

  StudyRoomAmbientTrack _current = StudyRoomAmbientTrack.none;
  StudyRoomAmbientTrack get current => _current;

  Future<void> setTrack(StudyRoomAmbientTrack track) async {
    if (_current == track && _player != null) return;
    _current = track;
    await _player?.stop();
    await _player?.dispose();
    _player = null;
    final path = track.assetPath;
    if (path == null) return;
    try {
      final p = AudioPlayer();
      await p.setReleaseMode(ReleaseMode.loop);
      await p.play(AssetSource(path));
      _player = p;
    } catch (e) {
      debugPrint('[StudyRoomAmbientPlayer] play failed: $e');
    }
  }

  Future<void> stop() async {
    _current = StudyRoomAmbientTrack.none;
    await _player?.stop();
    await _player?.dispose();
    _player = null;
  }

  Future<void> dispose() async {
    await stop();
  }
}
