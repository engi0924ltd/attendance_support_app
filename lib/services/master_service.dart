import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/dropdown_options.dart';
import 'api_service.dart';

/// マスタデータ（利用者リストやプルダウン選択肢）を取得する機能
class MasterService {
  final ApiService _apiService;

  MasterService({String? gasUrl}) : _apiService = ApiService(facilityGasUrl: gasUrl);

  // キャッシュのキー
  static const String _cacheKeyDropdowns = 'cached_dropdown_options';
  static const String _cacheKeyTimestamp = 'cached_dropdown_timestamp';
  static const String _cacheKeyUsers = 'cached_users';
  static const String _cacheKeyUsersTimestamp = 'cached_users_timestamp';
  static const String _cacheKeyAlerts = 'cached_evaluation_alerts';
  static const String _cacheKeyAlertsTimestamp = 'cached_alerts_timestamp';

  // キャッシュの有効期限
  static const Duration _dropdownsCacheExpiry = Duration(hours: 24);  // 24時間
  static const Duration _usersCacheExpiry = Duration(hours: 1);       // 1時間
  static const Duration _alertsCacheExpiry = Duration(minutes: 15);   // 15分

  /// 在籍中の利用者一覧を取得（キャッシュ機能付き）
  Future<List<User>> getActiveUsers({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      // キャッシュから取得を試みる
      final cachedUsers = await _getCachedUsers();
      if (cachedUsers != null) {
        return cachedUsers;
      }
    }

    // APIから取得
    final response = await _apiService.get('master/users');
    final List<dynamic> userList = response['users'] ?? [];
    final users = userList.map((json) => User.fromJson(json)).toList();

    // キャッシュに保存
    await _cacheUsers(users);

    return users;
  }

  /// 全利用者一覧を取得（退所済み含む）
  /// 過去の実績記録画面用
  Future<List<User>> getAllUsers() async {
    final response = await _apiService.get('master/all-users');
    final List<dynamic> userList = response['users'] ?? [];
    return userList.map((json) => User.fromJson(json)).toList();
  }

  /// キャッシュされた利用者一覧を取得
  Future<List<User>?> _getCachedUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // キャッシュの有効期限をチェック
      final timestampStr = prefs.getString(_cacheKeyUsersTimestamp);
      if (timestampStr != null) {
        final timestamp = DateTime.parse(timestampStr);
        final now = DateTime.now();

        if (now.difference(timestamp) < _usersCacheExpiry) {
          // キャッシュが有効期限内
          final cachedJson = prefs.getString(_cacheKeyUsers);
          if (cachedJson != null) {
            final List<dynamic> jsonList = jsonDecode(cachedJson);
            return jsonList.map((json) => User.fromJson(json)).toList();
          }
        }
      }
    } catch (e) {
      // キャッシュの読み込みに失敗した場合は無視
    }
    return null;
  }

  /// 利用者一覧をキャッシュに保存
  Future<void> _cacheUsers(List<User> users) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = users.map((u) => u.toJson()).toList();
      await prefs.setString(_cacheKeyUsers, jsonEncode(jsonList));
      await prefs.setString(_cacheKeyUsersTimestamp, DateTime.now().toIso8601String());
    } catch (e) {
      // キャッシュの保存に失敗しても続行
    }
  }

  /// 利用者キャッシュをクリア
  Future<void> clearUsersCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKeyUsers);
    await prefs.remove(_cacheKeyUsersTimestamp);
  }

  /// プルダウンの選択肢を取得（キャッシュ機能付き・24時間）
  Future<DropdownOptions> getDropdownOptions({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      // キャッシュから取得を試みる
      final cachedOptions = await _getCachedDropdownOptions();
      if (cachedOptions != null) {
        print('📦 [CACHE] master/dropdowns: キャッシュから取得');
        return cachedOptions;
      }
    }

    // APIから取得
    print('🌐 [API] master/dropdowns: APIから取得');
    final response = await _apiService.get('master/dropdowns');
    final options = DropdownOptions.fromJson(response);

    // キャッシュに保存
    await _cacheDropdownOptions(options);

    return options;
  }

  /// キャッシュされたプルダウン選択肢を取得
  Future<DropdownOptions?> _getCachedDropdownOptions() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // キャッシュの有効期限をチェック
      final timestampStr = prefs.getString(_cacheKeyTimestamp);
      if (timestampStr != null) {
        final timestamp = DateTime.parse(timestampStr);
        final now = DateTime.now();

        if (now.difference(timestamp) < _dropdownsCacheExpiry) {
          // キャッシュが有効期限内
          final cachedJson = prefs.getString(_cacheKeyDropdowns);
          if (cachedJson != null) {
            final Map<String, dynamic> json = jsonDecode(cachedJson);
            return DropdownOptions.fromJson(json);
          }
        }
      }
    } catch (e) {
      // キャッシュの読み込みに失敗した場合は無視
    }

    return null;
  }

  /// プルダウン選択肢をキャッシュに保存
  Future<void> _cacheDropdownOptions(DropdownOptions options) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 選択肢をJSON化して保存
      final Map<String, dynamic> json = {
        'scheduledUse': options.scheduledUse,
        'attendanceStatus': options.attendanceStatus,
        'tasks': options.tasks,
        'healthCondition': options.healthCondition,
        'sleepStatus': options.sleepStatus,
        'fatigue': options.fatigue,
        'stress': options.stress,
        'lunchBreak': options.lunchBreak,
        'shortBreak': options.shortBreak,
        'otherBreak': options.otherBreak,
        'specialNotes': options.specialNotes,
        'breaks': options.breaks,
        'workLocations': options.workLocations,
        'qualifications': options.qualifications,
        'placements': options.placements,
        'scheduledWeekly': options.scheduledWeekly,
        'recorders': options.recorders,
        'workEvaluations': options.workEvaluations,
        'employmentEvaluations': options.employmentEvaluations,
        'workMotivations': options.workMotivations,
        'communications': options.communications,
        'evaluations': options.evaluations,
        'rosterStatus': options.rosterStatus,
        'lifeProtection': options.lifeProtection,
        'disabilityPension': options.disabilityPension,
        'disabilityGrade': options.disabilityGrade,
        'disabilityType': options.disabilityType,
        'supportLevel': options.supportLevel,
        'contractType': options.contractType,
        'employmentSupport': options.employmentSupport,
        'checkinTimeList': options.checkinTimeList,
        'checkoutTimeList': options.checkoutTimeList,
      };

      await prefs.setString(_cacheKeyDropdowns, jsonEncode(json));
      await prefs.setString(_cacheKeyTimestamp, DateTime.now().toIso8601String());
    } catch (e) {
      // キャッシュの保存に失敗しても続行
    }
  }

  /// プルダウン選択肢のキャッシュをクリア
  Future<void> clearDropdownCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKeyDropdowns);
    await prefs.remove(_cacheKeyTimestamp);
  }

  /// 評価アラート情報を取得（キャッシュ機能付き・15分）
  /// 在宅支援（1週間以内）または施設外支援（2週間以内）の評価が必要な利用者を返す
  Future<List<EvaluationAlert>> getEvaluationAlerts({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      // キャッシュから取得を試みる
      final cachedAlerts = await _getCachedAlerts();
      if (cachedAlerts != null) {
        print('📦 [CACHE] evaluation-alerts: キャッシュから取得');
        return cachedAlerts;
      }
    }

    try {
      print('🌐 [API] evaluation-alerts: APIから取得');
      final response = await _apiService.get('master/evaluation-alerts');
      final List<dynamic> alertList = response['alerts'] ?? [];
      final alerts = alertList.map((json) => EvaluationAlert.fromJson(json)).toList();

      // キャッシュに保存
      await _cacheAlerts(alerts);

      return alerts;
    } catch (e) {
      // エラー時は空のリストを返す（UIに影響しないように）
      return [];
    }
  }

  /// キャッシュされた評価アラートを取得
  Future<List<EvaluationAlert>?> _getCachedAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // キャッシュの有効期限をチェック
      final timestampStr = prefs.getString(_cacheKeyAlertsTimestamp);
      if (timestampStr != null) {
        final timestamp = DateTime.parse(timestampStr);
        final now = DateTime.now();

        if (now.difference(timestamp) < _alertsCacheExpiry) {
          // キャッシュが有効期限内
          final cachedJson = prefs.getString(_cacheKeyAlerts);
          if (cachedJson != null) {
            final List<dynamic> jsonList = jsonDecode(cachedJson);
            return jsonList.map((json) => EvaluationAlert.fromJson(json)).toList();
          }
        }
      }
    } catch (e) {
      // キャッシュの読み込みに失敗した場合は無視
    }
    return null;
  }

  /// 評価アラートをキャッシュに保存
  Future<void> _cacheAlerts(List<EvaluationAlert> alerts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = alerts.map((a) => {
        'userName': a.userName,
        'alertType': a.alertType,
        'daysSinceLastEval': a.daysSinceLastEval,
        'lastEvalDate': a.lastEvalDate,
        'message': a.message,
      }).toList();
      await prefs.setString(_cacheKeyAlerts, jsonEncode(jsonList));
      await prefs.setString(_cacheKeyAlertsTimestamp, DateTime.now().toIso8601String());
    } catch (e) {
      // キャッシュの保存に失敗しても続行
    }
  }

  /// 評価アラートのキャッシュをクリア
  Future<void> clearAlertsCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKeyAlerts);
    await prefs.remove(_cacheKeyAlertsTimestamp);
  }
}

/// 評価アラート情報を表すモデル
class EvaluationAlert {
  final String userName;
  final String alertType; // 'home' or 'external'
  final int daysSinceLastEval;
  final String? lastEvalDate;
  final String message;

  EvaluationAlert({
    required this.userName,
    required this.alertType,
    required this.daysSinceLastEval,
    this.lastEvalDate,
    required this.message,
  });

  factory EvaluationAlert.fromJson(Map<String, dynamic> json) {
    return EvaluationAlert(
      userName: json['userName'] ?? '',
      alertType: json['alertType'] ?? '',
      daysSinceLastEval: json['daysSinceLastEval'] ?? 0,
      lastEvalDate: json['lastEvalDate'],
      message: json['message'] ?? '',
    );
  }

  /// 表示用のアラートメッセージ
  String get alertMessage {
    // GASからのメッセージがあればそれを使用
    if (message.isNotEmpty) {
      return message;
    }
    final typeLabel = alertType == 'home' ? '在宅支援' : '施設外支援';
    if (lastEvalDate != null) {
      return '$typeLabel評価が必要です（前回: $lastEvalDate, $daysSinceLastEval日経過）';
    } else {
      return '$typeLabel評価が必要です（評価未実施）';
    }
  }
}
