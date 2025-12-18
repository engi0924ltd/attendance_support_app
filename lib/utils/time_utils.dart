/// 時間変換ユーティリティ
class TimeUtils {
  /// 入力時間を15分近似値リストから最も近い時間に変換
  ///
  /// [inputTime]: 入力時間（"HH:mm"形式）
  /// [timeList]: 時間リスト（例: ["10:00", "10:15", "10:30", ...]）
  ///
  /// 返り値: 最も近い時間（例: "9:18" → "9:15"、"9:23" → "9:30"）
  static String roundToNearestTime(String inputTime, List<String> timeList) {
    print('⏰ [TimeUtils] roundToNearestTime 呼び出し: inputTime=$inputTime, listSize=${timeList.length}');

    // 時間リストが空の場合は入力時間をそのまま返す
    if (timeList.isEmpty) {
      print('⚠️ [TimeUtils] 時間リストが空のため、元の時間を返します');
      return inputTime;
    }

    try {
      // 入力時間を分に変換
      final inputMinutes = _timeToMinutes(inputTime);
      print('⏰ [TimeUtils] 入力時間を分に変換: $inputTime → $inputMinutes分');

      // 最も近い時間を見つける
      String nearestTime = timeList.first;
      int minDifference = 999999; // 大きな初期値

      for (final time in timeList) {
        final timeMinutes = _timeToMinutes(time);
        final difference = (inputMinutes - timeMinutes).abs();

        if (difference < minDifference) {
          minDifference = difference;
          nearestTime = time;
        }
      }

      print('✅ [TimeUtils] 最も近い時間を発見: $nearestTime (差分: $minDifference分)');
      return nearestTime;
    } catch (e) {
      // エラーが発生した場合は入力時間をそのまま返す
      print('❌ [TimeUtils] エラー発生: $e');
      return inputTime;
    }
  }

  /// 時間文字列（"HH:mm"）を分に変換
  ///
  /// 例: "9:15" → 555 (9 * 60 + 15)
  static int _timeToMinutes(String time) {
    final parts = time.split(':');
    if (parts.length != 2) {
      throw FormatException('Invalid time format: $time');
    }

    final hours = int.parse(parts[0]);
    final minutes = int.parse(parts[1]);

    return hours * 60 + minutes;
  }

  /// 分を時間文字列（"HH:mm"）に変換
  ///
  /// 例: 555 → "9:15"
  static String _minutesToTime(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
  }
}
