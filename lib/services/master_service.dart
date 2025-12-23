import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/dropdown_options.dart';
import 'api_service.dart';

/// マスタデータ（利用者リストやプルダウン選択肢）を取得する機能
class MasterService {
  final ApiService _apiService = ApiService();

  // キャッシュのキー
  static const String _cacheKeyDropdowns = 'cached_dropdown_options';
  static const String _cacheKeyTimestamp = 'cached_dropdown_timestamp';

  // キャッシュの有効期限（24時間）
  static const Duration _cacheExpiry = Duration(hours: 24);

  /// 在籍中の利用者一覧を取得
  Future<List<User>> getActiveUsers() async {
    final response = await _apiService.get('master/users');

    final List<dynamic> userList = response['users'] ?? [];
    return userList.map((json) => User.fromJson(json)).toList();
  }

  /// プルダウンの選択肢を取得（キャッシュ機能付き）
  Future<DropdownOptions> getDropdownOptions({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      // キャッシュから取得を試みる
      final cachedOptions = await _getCachedDropdownOptions();
      if (cachedOptions != null) {
        return cachedOptions;
      }
    }

    // APIから取得
    final response = await _apiService.get('master/dropdowns');

    // 【デバッグ】APIレスポンスを確認
    print('🔧 API Response (workLocations): ${response['workLocations']}');
    print('🔧 API Response (recorders): ${response['recorders']}');

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

        if (now.difference(timestamp) < _cacheExpiry) {
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
        'evaluations': options.evaluations,
        'scheduledWeekly': options.scheduledWeekly,
        'recorders': options.recorders, // 【追加】記録者
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
}
