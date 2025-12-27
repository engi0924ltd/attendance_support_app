import '../models/attendance.dart';
import 'api_service.dart';

/// 勤怠データ（出勤・退勤）を扱う機能
class AttendanceService {
  final ApiService _apiService;

  AttendanceService({String? gasUrl}) : _apiService = ApiService(facilityGasUrl: gasUrl);

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

  /// Chatworkルームを持つ利用者一覧を取得
  Future<List<Map<String, dynamic>>> getChatworkUsers() async {
    final response = await _apiService.get('chatwork/users');

    final List<dynamic> users = response['users'] ?? [];

    return users.map((user) => Map<String, dynamic>.from(user)).toList();
  }

  /// Chatworkメッセージを送信（選択送信対応）
  Future<Map<String, dynamic>> sendChatworkBroadcast(
    String message, {
    List<String>? selectedUsers,
  }) async {
    final response = await _apiService.post('chatwork/broadcast', {
      'message': message,
      if (selectedUsers != null) 'selectedUsers': selectedUsers,
    });
    return response;
  }

  /// Chatwork APIキーを施設GASに設定
  Future<Map<String, dynamic>> setChatworkApiKey(String apiKey) async {
    final response = await _apiService.post('chatwork/set-api-key', {
      'apiKey': apiKey,
    });
    return response;
  }

  /// 施設全体の統計を取得
  Future<Map<String, dynamic>> getFacilityStats() async {
    final response = await _apiService.get('analytics/facility-stats');
    return response;
  }

  /// 曜日別出勤予定を取得（詳細データ付き）
  Future<Map<String, dynamic>> getWeeklyScheduleWithDetails() async {
    final response = await _apiService.get('analytics/weekly-schedule');
    final Map<String, dynamic> scheduleData = response['schedule'] ?? {};
    final Map<String, dynamic> detailsData = response['details'] ?? {};

    // schedule型変換
    final schedule = <String, Map<String, int>>{};
    scheduleData.forEach((weekday, types) {
      if (types is Map) {
        schedule[weekday] = {};
        types.forEach((type, count) {
          schedule[weekday]![type.toString()] = (count as num).toInt();
        });
      }
    });

    // details型変換
    final details = <String, Map<String, Map<String, int>>>{};
    detailsData.forEach((weekday, categories) {
      if (categories is Map) {
        details[weekday] = {};
        categories.forEach((category, values) {
          if (values is Map) {
            details[weekday]![category.toString()] = {};
            values.forEach((value, count) {
              details[weekday]![category.toString()]![value.toString()] =
                  (count as num).toInt();
            });
          }
        });
      }
    });

    return {'schedule': schedule, 'details': details};
  }

  /// 利用者個人の統計を取得
  Future<Map<String, dynamic>> getUserStats(String userName) async {
    final encodedName = Uri.encodeComponent(userName);
    final response = await _apiService.get('analytics/user-stats/$encodedName');
    return response;
  }
}
