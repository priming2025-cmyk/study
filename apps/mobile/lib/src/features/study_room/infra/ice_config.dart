import 'package:flutter_dotenv/flutter_dotenv.dart';

class IceConfig {
  static Map<String, dynamic> peerConnectionConfig() {
    final turnUrl = dotenv.env['TURN_URL'] ?? '';
    final turnUsername = dotenv.env['TURN_USERNAME'] ?? '';
    final turnCredential = dotenv.env['TURN_CREDENTIAL'] ?? '';

    final iceServers = <Map<String, dynamic>>[
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ];

    final hasTurn = turnUrl.trim().isNotEmpty &&
        turnUsername.trim().isNotEmpty &&
        turnCredential.trim().isNotEmpty;
    if (hasTurn) {
      iceServers.add(
        {
          'urls': turnUrl.trim(),
          'username': turnUsername.trim(),
          'credential': turnCredential.trim(),
        },
      );
    }

    return {
      'iceServers': iceServers,
      // For MVP: balance between connectivity and cost.
      'sdpSemantics': 'unified-plan',
    };
  }

  static Map<String, dynamic> mediaConstraints() => {
        'audio': true,
        'video': {'facingMode': 'user'},
      };

  static Map<String, dynamic> offerConstraints() => {
        'offerToReceiveAudio': 1,
        'offerToReceiveVideo': 1,
      };
}

