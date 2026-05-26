import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase에 등록한 provider id와 **문자 하나까지** 동일해야 합니다.
abstract final class SetudyOAuth {
  static const naver = OAuthProvider('naver');
}
