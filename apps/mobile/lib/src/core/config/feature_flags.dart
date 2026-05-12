import 'package:supabase_flutter/supabase_flutter.dart';

/// 기능 플래그 모음.
class FeatureFlags {
  /// 스터디방 활성 여부: 로그인한 사용자는 항상 접근 가능.
  static bool get studyRoomEnabled {
    return Supabase.instance.client.auth.currentSession != null;
  }
}
