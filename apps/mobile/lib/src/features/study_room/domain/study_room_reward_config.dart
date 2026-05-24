/// 셋터디 퇴장 시 추가 **블럭** 보너스 설정.
///
/// 후보 (제품에서 하나 선택):
/// - **A (현재 적용)**: 집중 5분 이상이면 **+3블럭** 고정
/// - **B**: 집중 10분 이상이면 **+5블럭** 고정
/// - **C**: 집중 10분마다 **+1블럭** (30분이면 +3)
abstract final class StudyRoomRewardConfig {
  /// 현재 선택: A
  static const int bonusBlocks = 3;

  static const int minFocusedSecondsForBonus = 5 * 60;

  /// B안
  // static const int bonusBlocks = 5;
  // static const int minFocusedSecondsForBonus = 10 * 60;

  /// C안
  // static int bonusBlocksForFocusedSeconds(int focusedSeconds) =>
  //     focusedSeconds >= 10 * 60 ? focusedSeconds ~/ (10 * 60) : 0;

  static int blocksToAward(int focusedSeconds) {
    if (focusedSeconds < minFocusedSecondsForBonus) return 0;
    return bonusBlocks;
  }
}
