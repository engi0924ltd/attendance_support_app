import '../models/attendance.dart';
import 'api_service.dart';

/// 勤怠データ（出勤・退勤）を扱う機能
class AttendanceService {
  final ApiService _apiService = ApiService();

  /// 出勤登録
  Future<Map<String, dynamic>> checkin(Attendance attendance) async {
    final response = await _apiService.post(
      'attendance/checkin',
      attendance.toJson(),
    );
    return response;
  }

  /// 退勤登録
  Future<Map<String, dynamic>> checkout(
    String userName,
    String date,
    String checkoutTime, {
    String? fatigue,
    String? stress,
    String? lunchBreak,
    String? shortBreak,
    String? otherBreak,
    String? checkoutComment,
  }) async {
    final response = await _apiService.post('attendance/checkout', {
      'userName': userName,
      'date': date,
      'checkoutTime': checkoutTime,
      'fatigue': fatigue,
      'stress': stress,
      'lunchBreak': lunchBreak,
      'shortBreak': shortBreak,
      'otherBreak': otherBreak,
      'checkoutComment': checkoutComment,
    });
    return response;
  }

  /// 指定日の全勤怠一覧を取得（支援者用）
  Future<List<Attendance>> getDailyAttendance(String date) async {
    final response = await _apiService.get('attendance/daily/$date');

    final List<dynamic> records = response['records'] ?? [];

    return records.map((json) => Attendance.fromJson(json)).toList();
  }

  /// 指定日の出勤予定者一覧を取得（支援者用）
  Future<List<Map<String, dynamic>>> getScheduledUsers(String date) async {
    final response = await _apiService.get('attendance/scheduled/$date');

    final List<dynamic> scheduledUsers = response['scheduledUsers'] ?? [];

    return scheduledUsers.map((item) {
      return {
        'userName': item['userName'],
        'scheduledAttendance': item['scheduledAttendance'],
        'hasCheckedIn': item['hasCheckedIn'],
        'attendance': item['attendance'] != null
            ? Attendance.fromJson(item['attendance'])
            : null,
      };
    }).toList();
  }

  /// 特定利用者の勤怠データを取得
  Future<Attendance?> getUserAttendance(String userName, String date) async {
    final response = await _apiService.get('attendance/user/$userName/$date');

    if (response['record'] != null) {
      return Attendance.fromJson(response['record']);
    }
    return null;
  }

  /// 勤怠データを更新（支援者用）
  Future<Map<String, dynamic>> updateAttendance(
    String userName,
    String date, {
    String? attendanceStatus,
    String? checkinTime,
    String? checkoutTime,
    String? lunchBreak,
    String? shortBreak,
    String? otherBreak,
  }) async {
    final response = await _apiService.post('attendance/update', {
      'userName': userName,
      'date': date,
      'attendanceStatus': attendanceStatus,
      'checkinTime': checkinTime,
      'checkoutTime': checkoutTime,
      'lunchBreak': lunchBreak,
      'shortBreak': shortBreak,
      'otherBreak': otherBreak,
    });
    return response;
  }

  /// 特定利用者の過去記録一覧を取得
  Future<List<Attendance>> getUserHistory(String userName) async {
    final encodedName = Uri.encodeComponent(userName);
    final response = await _apiService.get('attendance/history/$encodedName');

    final List<dynamic> records = response['records'] ?? [];

    return records.map((json) => Attendance.fromJson(json)).toList();
  }

  /// 複数利用者の健康履歴をバッチ取得（過去7回分）
  Future<Map<String, List<Map<String, dynamic>>>> getHealthBatch(
    List<String> userNames,
  ) async {
    if (userNames.isEmpty) {
      return {};
    }

    final encodedNames = Uri.encodeComponent(userNames.join(','));
    final response = await _apiService.get('attendance/health-batch/$encodedNames');

    final Map<String, dynamic> healthData = response['healthData'] ?? {};

    // 型変換
    final result = <String, List<Map<String, dynamic>>>{};
    healthData.forEach((userName, records) {
      if (records is List) {
        result[userName] = records.map((r) => Map<String, dynamic>.from(r)).toList();
      }
    });

    return result;
  }
}
