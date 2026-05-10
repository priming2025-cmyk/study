import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class VideoTile extends StatelessWidget {
  final String label;
  final RTCVideoRenderer renderer;

  const VideoTile({super.key, required this.label, required this.renderer});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black12),
          RTCVideoView(renderer, mirror: true),
          Align(
            alignment: Alignment.bottomLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              color: Colors.black54,
              child: Text(label, style: const TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

