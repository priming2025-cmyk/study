/// 방 이름을 비웠을 때 쓰는 기본 표시명.
const kDefaultStudyRoomName = '우리셋';

/// 편집 시 입력란을 비워 두는 레거시·기본 이름.
const kLegacyDefaultStudyRoomNames = {'셋', kDefaultStudyRoomName};

/// 설정 시트·만들기 폼에 보여 줄 이름 (기본명이면 빈 칸).
String displayRoomNameForEdit(String? name) {
  final trimmed = (name ?? '').trim();
  if (trimmed.isEmpty || kLegacyDefaultStudyRoomNames.contains(trimmed)) {
    return '';
  }
  return trimmed;
}

/// 저장·DB 반영용 이름.
String resolveStudyRoomName(String input) {
  final trimmed = input.trim();
  return trimmed.isEmpty ? kDefaultStudyRoomName : trimmed;
}
