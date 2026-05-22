import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 연락처 기반 친구 찾기 (카톡/인스타 스타일 UX).
class ContactsFriendService {
  static const _syncedKey = 'setudy_contacts_synced_v1';

  /// 연락처 읽기 권한 요청 후 이름·전화번호 목록 반환.
  static Future<List<ContactFriendCandidate>> loadDeviceContacts() async {
    if (!await FlutterContacts.requestPermission(readonly: true)) {
      return const [];
    }
    final contacts = await FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: false,
    );
    final out = <ContactFriendCandidate>[];
    for (final c in contacts) {
      final name = c.displayName.trim();
      if (name.isEmpty) continue;
      for (final phone in c.phones) {
        final normalized = _normalizePhone(phone.number);
        if (normalized.length >= 8) {
          out.add(ContactFriendCandidate(name: name, phone: normalized));
        }
      }
    }
    return out;
  }

  /// 서버에 등록된 셋터디 사용자와 매칭 (profiles.phone_hash 등 — 없으면 로컬만).
  static Future<List<ContactFriendCandidate>> matchSettudyUsers(
    List<ContactFriendCandidate> local,
  ) async {
    try {
      final phones = local.map((e) => e.phone).toSet().toList();
      if (phones.isEmpty) return local;
      final result = await Supabase.instance.client
          .from('profiles')
          .select('id, display_name, phone')
          .filter('phone', 'in', '(${phones.map((p) => '"$p"').join(',')})')
          .limit(50);
      final matchedIds = <String>{};
      for (final row in result as List) {
        final phone = row['phone'] as String?;
        if (phone == null) continue;
        matchedIds.add(phone);
      }
      return local
          .map(
            (e) => e.copyWith(
              onSettudy: matchedIds.contains(e.phone),
            ),
          )
          .toList();
    } catch (_) {
      return local;
    }
  }

  static Future<void> markSynced() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool(_syncedKey, true);
  }

  static Future<bool> wasSynced() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_syncedKey) ?? false;
  }

  static String _normalizePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.startsWith('+82')) {
      return '0${digits.substring(3)}';
    }
    return digits.replaceAll(RegExp(r'\D'), '');
  }
}

class ContactFriendCandidate {
  final String name;
  final String phone;
  final bool onSettudy;

  const ContactFriendCandidate({
    required this.name,
    required this.phone,
    this.onSettudy = false,
  });

  ContactFriendCandidate copyWith({bool? onSettudy}) => ContactFriendCandidate(
        name: name,
        phone: phone,
        onSettudy: onSettudy ?? this.onSettudy,
      );
}
