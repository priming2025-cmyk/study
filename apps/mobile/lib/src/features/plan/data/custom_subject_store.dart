import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 사용자 정의 과목 + 색상 (로컬 저장).
class CustomSubject {
  final String name;
  final int colorValue;

  const CustomSubject({required this.name, required this.colorValue});

  Color get color => Color(colorValue);

  Map<String, dynamic> toJson() => {
        'name': name,
        'color': colorValue,
      };

  factory CustomSubject.fromJson(Map<String, dynamic> j) => CustomSubject(
        name: j['name'] as String,
        colorValue: j['color'] as int,
      );
}

const _key = 'setudy_custom_subjects_v1';

const defaultSubjects = [
  CustomSubject(name: '국어', colorValue: 0xFFEF4444),
  CustomSubject(name: '영어', colorValue: 0xFF3B82F6),
  CustomSubject(name: '수학', colorValue: 0xFFF59E0B),
  CustomSubject(name: '과학', colorValue: 0xFF10B981),
  CustomSubject(name: '사회', colorValue: 0xFF8B5CF6),
];

class CustomSubjectStore {
  static Future<List<CustomSubject>> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    if (raw == null || raw.isEmpty) return List.from(defaultSubjects);
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => CustomSubject.fromJson(e as Map<String, dynamic>))
          .toList();
      return list.isEmpty ? List.from(defaultSubjects) : list;
    } catch (_) {
      return List.from(defaultSubjects);
    }
  }

  static Future<void> save(List<CustomSubject> subjects) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
      _key,
      jsonEncode(subjects.map((s) => s.toJson()).toList()),
    );
  }

  static bool isDefault(String name) =>
      defaultSubjects.any((s) => s.name == name);

  static Future<bool> remove(String name) async {
    final list = await load();
    final next = list.where((s) => s.name != name).toList();
    if (next.length == list.length) return false;
    await save(next);
    return true;
  }

  static Future<void> upsert(String name, int colorValue) async {
    final list = await load();
    final i = list.indexWhere((s) => s.name == name);
    if (i >= 0) {
      list[i] = CustomSubject(name: name, colorValue: colorValue);
    } else {
      list.add(CustomSubject(name: name, colorValue: colorValue));
    }
    await save(list);
  }

  static Color colorFor(String subject, List<CustomSubject> customs) {
    for (final s in customs) {
      if (s.name == subject) return s.color;
    }
    for (final s in defaultSubjects) {
      if (s.name == subject) return s.color;
    }
    return const Color(0xFF94A3B8);
  }
}
