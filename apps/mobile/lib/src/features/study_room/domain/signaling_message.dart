class SignalingMessage {
  final String type; // join | leave | offer | answer | ice
  final String from;
  final String? to;
  final Map<String, dynamic> payload;

  const SignalingMessage({
    required this.type,
    required this.from,
    required this.to,
    required this.payload,
  });

  factory SignalingMessage.fromJson(Map<String, dynamic> json) {
    return SignalingMessage(
      type: json['type'] as String,
      from: json['from'] as String,
      to: json['to'] as String?,
      payload: (json['payload'] as Map).cast<String, dynamic>(),
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'from': from,
        'to': to,
        'payload': payload,
      };
}

