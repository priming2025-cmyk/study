import 'package:shared_preferences/shared_preferences.dart';

/// 즉시 점수가 이 값 이상일 때 **집중 초**를 누적합니다.
/// 집중/보통 등 UI 단계의 ‘집중’ 하한에도 같은 기준을 씁니다(단계 라벨은 롤링과 혼합 점수로 계산).
///
/// 선택지는 5단계 고정. 기본 [kDefaultEngagedMinScore].
const List<int> kEngagedMinScoreOptions = [80, 65, 50, 35, 20];

const int kDefaultEngagedMinScore = 50;

const _prefKey = 'session_engaged_min_score_v1';

int normalizeEngagedMinScore(int value) {
  if (kEngagedMinScoreOptions.contains(value)) return value;
  return kDefaultEngagedMinScore;
}

Future<int> loadEngagedMinScore() async {
  try {
    final sp = await SharedPreferences.getInstance();
    final v = sp.getInt(_prefKey);
    if (v == null) return kDefaultEngagedMinScore;
    return normalizeEngagedMinScore(v);
  } catch (_) {
    return kDefaultEngagedMinScore;
  }
}

Future<void> saveEngagedMinScore(int value) async {
  final sp = await SharedPreferences.getInstance();
  await sp.setInt(_prefKey, normalizeEngagedMinScore(value));
}
