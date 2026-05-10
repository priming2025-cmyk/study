import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../../core/supabase/supabase_client.dart';
import '../domain/signaling_message.dart';
import 'ice_config.dart';
import 'study_room_signaling.dart';

class StudyRoomController {
  final StudyRoomSignaling _signaling = StudyRoomSignaling();
  final Map<String, RTCPeerConnection> _pcs = {};
  MediaStream? _localStream;

  final _remoteStreams = StreamController<Map<String, MediaStream>>.broadcast();
  final Map<String, MediaStream> _remote = {};

  Stream<Map<String, MediaStream>> get remoteStreams => _remoteStreams.stream;
  MediaStream? get localStream => _localStream;

  String? _roomId;
  String? _selfId;
  StreamSubscription<SignalingMessage>? _sub;

  Future<String> createAndJoinRoom({required String name}) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw StateError('Not authenticated');

    final room = await supabase
        .from('study_rooms')
        .insert({'owner_id': userId, 'name': name, 'max_peers': 4})
        .select('id')
        .single();

    final roomId = room['id'] as String;
    await joinRoom(roomId: roomId);
    return roomId;
  }

  Future<void> joinRoom({required String roomId}) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw StateError('Not authenticated');

    _roomId = roomId;
    _selfId = userId;

    // Track membership (metadata only)
    await supabase.from('study_room_members').upsert(
      {'room_id': roomId, 'user_id': userId},
      onConflict: 'room_id,user_id',
    );

    try {
      _localStream =
          await navigator.mediaDevices.getUserMedia(IceConfig.mediaConstraints());
    } catch (e) {
      throw StateError(
        '마이크·카메라 권한이 필요해요. 브라우저나 기기 설정에서 허용한 뒤 다시 시도해 주세요. ($e)',
      );
    }

    await _signaling.connect(roomId: roomId, selfId: userId);
    _sub?.cancel();
    _sub = _signaling.messages.listen(_onMessage);
  }

  Future<void> leave() async {
    final roomId = _roomId;
    final selfId = _selfId;
    if (roomId != null && selfId != null) {
      try {
        await _signaling.send(
          roomId: roomId,
          message: SignalingMessage(type: 'leave', from: selfId, to: null, payload: const {}),
        );
      } catch (_) {}

      try {
        await supabase
            .from('study_room_members')
            .update({'left_at': DateTime.now().toUtc().toIso8601String()})
            .eq('room_id', roomId)
            .eq('user_id', selfId);
      } catch (_) {}
    }

    await _sub?.cancel();
    _sub = null;

    for (final pc in _pcs.values) {
      try {
        await pc.close();
      } catch (_) {}
    }
    _pcs.clear();

    for (final s in _remote.values) {
      try {
        await s.dispose();
      } catch (_) {}
    }
    _remote.clear();
    _remoteStreams.add(Map.of(_remote));

    try {
      await _localStream?.dispose();
    } catch (_) {}
    _localStream = null;

    await _signaling.disconnect();
    _roomId = null;
    _selfId = null;
  }

  Future<void> dispose() async {
    await leave();
    await _signaling.dispose();
    await _remoteStreams.close();
  }

  Future<void> _onMessage(SignalingMessage msg) async {
    switch (msg.type) {
      case 'join':
        await _handleJoin(from: msg.from);
        break;
      case 'offer':
        await _handleOffer(from: msg.from, sdp: msg.payload['sdp'] as String);
        break;
      case 'answer':
        await _handleAnswer(from: msg.from, sdp: msg.payload['sdp'] as String);
        break;
      case 'ice':
        await _handleIce(from: msg.from, candidate: msg.payload);
        break;
      case 'leave':
        await _handleLeave(from: msg.from);
        break;
    }
  }

  Future<void> _handleJoin({required String from}) async {
    // Deterministic: only the lexicographically smaller id creates the offer.
    final selfId = _selfId;
    final roomId = _roomId;
    if (selfId == null || roomId == null) return;
    if (from == selfId) return;
    if (selfId.compareTo(from) > 0) return;
    await _ensurePc(remoteId: from);
    final pc = _pcs[from]!;
    final offer = await pc.createOffer(IceConfig.offerConstraints());
    await pc.setLocalDescription(offer);

    await _signaling.send(
      roomId: roomId,
      message: SignalingMessage(
        type: 'offer',
        from: selfId,
        to: from,
        payload: {'sdp': offer.sdp},
      ),
    );
  }

  Future<void> _handleOffer({required String from, required String sdp}) async {
    final selfId = _selfId;
    final roomId = _roomId;
    if (selfId == null || roomId == null) return;
    await _ensurePc(remoteId: from);
    final pc = _pcs[from]!;
    await pc.setRemoteDescription(RTCSessionDescription(sdp, 'offer'));
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);

    await _signaling.send(
      roomId: roomId,
      message: SignalingMessage(
        type: 'answer',
        from: selfId,
        to: from,
        payload: {'sdp': answer.sdp},
      ),
    );
  }

  Future<void> _handleAnswer({required String from, required String sdp}) async {
    final pc = _pcs[from];
    if (pc == null) return;
    await pc.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
  }

  Future<void> _handleIce({required String from, required Map<String, dynamic> candidate}) async {
    final pc = _pcs[from];
    if (pc == null) return;
    final c = RTCIceCandidate(
      candidate['candidate'] as String?,
      candidate['sdpMid'] as String?,
      candidate['sdpMLineIndex'] as int?,
    );
    await pc.addCandidate(c);
  }

  Future<void> _handleLeave({required String from}) async {
    final pc = _pcs.remove(from);
    try {
      await pc?.close();
    } catch (_) {}

    final stream = _remote.remove(from);
    try {
      await stream?.dispose();
    } catch (_) {}
    _remoteStreams.add(Map.of(_remote));
  }

  Future<void> _ensurePc({required String remoteId}) async {
    if (_pcs.containsKey(remoteId)) return;
    final roomId = _roomId;
    final selfId = _selfId;
    if (roomId == null || selfId == null) return;

    final pc = await createPeerConnection(IceConfig.peerConnectionConfig());
    _pcs[remoteId] = pc;

    final local = _localStream;
    if (local != null) {
      for (final track in local.getTracks()) {
        await pc.addTrack(track, local);
      }
    }

    pc.onIceCandidate = (c) async {
      if (c.candidate == null) return;
      await _signaling.send(
        roomId: roomId,
        message: SignalingMessage(
          type: 'ice',
          from: selfId,
          to: remoteId,
          payload: {
            'candidate': c.candidate,
            'sdpMid': c.sdpMid,
            'sdpMLineIndex': c.sdpMLineIndex,
          },
        ),
      );
    };

    pc.onTrack = (event) {
      final streams = event.streams;
      if (streams.isEmpty) return;
      _remote[remoteId] = streams.first;
      _remoteStreams.add(Map.of(_remote));
    };
  }
}

