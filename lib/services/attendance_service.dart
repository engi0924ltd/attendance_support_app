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
    String? checkoutComment,
  }) async {
    final response = await _apiService.post('attendance/checkout', {
      'userName': userName,
      'date': date,
      'checkoutTime': checkoutTime,
      'fatigue': fatigue,
      'stress': stress,
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

  /// 特定利用者の勤怠データを取得
  Future<Attendance?> getUserAttendance(String userName, String date) async {
    final response = await _apiService.get('attendance/user/$userName/$date');

    if (response['record'] != null) {
      return Attendance.fromJson(response['record']);
    }
    return null;
  }

  /// 勤怠データを更新（支援者用）
  Future<Map<String, dynamic>> updateAttendance(Attendance attendance) async {
    final response = await _apiService.put(
      'attendance/update/${attendance.rowId}',
      attendance.toJson(),
    );
    return response;
  }
}
