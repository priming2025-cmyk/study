import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_client.dart';

class LinkedStudent {
  final String id;
  final String? displayName;

  const LinkedStudent({required this.id, this.displayName});
}

class ChildSessionSummary {
  final String id;
  final DateTime startedAt;
  final int focusedSeconds;
  final String? subject;

  const ChildSessionSummary({
    required this.id,
    required this.startedAt,
    required this.focusedSeconds,
    this.subject,
  });
}

class FamilyRepository {
  const FamilyRepository();

  Future<String?> fetchMyRole() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;
    final row = await supabase
        .from('profiles')
        .select('role')
        .eq('id', userId)
        .maybeSingle();
    return row?['role'] as String?;
  }

  Future<List<LinkedStudent>> fetchLinkedStudents() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw const AuthException('Not authenticated');

    final links = await supabase
        .from('parent_links')
        .select('student_id')
        .eq('parent_id', userId);

    final out = <LinkedStudent>[];
    for (final row in links) {
      final sid = row['student_id'] as String;
      final p = await supabase
          .from('profiles')
          .select('display_name')
          .eq('id', sid)
          .maybeSingle();
      out.add(LinkedStudent(
        id: sid,
        displayName: p?['display_name'] as String?,
      ));
    }
    return out;
  }

  Future<void> linkStudent(String studentId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw const AuthException('Not authenticated');

    await supabase.from('parent_links').insert({
      'parent_id': userId,
      'student_id': studentId.trim(),
    });
  }

  Future<List<ChildSessionSummary>> fetchChildSessions(String studentId) async {
    final rows = await supabase
        .from('study_sessions')
        .select('id, started_at, focused_seconds, subject')
        .eq('user_id', studentId)
        .order('started_at', ascending: false)
        .limit(25);

    return rows
        .map(
          (e) => ChildSessionSummary(
            id: e['id'] as String,
            startedAt: DateTime.parse(e['started_at'] as String).toLocal(),
            focusedSeconds: ((e['focused_seconds'] ?? 0) as num).toInt(),
            subject: e['subject'] as String?,
          ),
        )
        .toList();
  }
}
