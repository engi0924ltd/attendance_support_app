import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

/// 担当業務管理サービス
class TasksService {
  final http.Client _client = http.Client();
  final String? facilityGasUrl;

  TasksService({this.facilityGasUrl});

  /// 使用するGAS URLを取得
  Future<String> get _gasUrl async {
    if (facilityGasUrl != null && facilityGasUrl!.isNotEmpty) {
      return facilityGasUrl!;
    }

    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('facility_gas_url');
    if (savedUrl != null && savedUrl.isNotEmpty) {
      return savedUrl;
    }

    return ApiConfig.baseUrl;
  }

  /// 担当業務一覧を取得
  Future<List<String>> getTasks() async {
    try {
      final gasUrl = await _gasUrl;
      final response = await _client
          .post(
            Uri.parse(gasUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'action': 'tasks/get'}),
          )
          .timeout(ApiConfig.timeout);

      final data = await _handleResponse(response);
      return List<String>.from(data['tasks'] ?? []);
    } catch (e) {
      return [];
    }
  }

  /// 担当業務を追加
  Future<bool> addTask(String name) async {
    try {
      final gasUrl = await _gasUrl;
      final response = await _client
          .post(
            Uri.parse(gasUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': 'tasks/add',
              'name': name,
            }),
          )
          .timeout(ApiConfig.timeout);

      await _handleResponse(response);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 担当業務を削除
  Future<bool> deleteTask(int index) async {
    try {
      final gasUrl = await _gasUrl;
      final response = await _client
          .post(
            Uri.parse(gasUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'action': 'tasks/delete',
              'index': index,
            }),
          )
          .timeout(ApiConfig.timeout);

      await _handleResponse(response);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// レスポンス処理（302リダイレクト対応）
  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    // 302リダイレクトの場合
    if (response.statusCode == 302) {
      final redirectMatch =
          RegExp(r'HREF="([^"]+)"').firstMatch(response.body);

      if (redirectMatch != null) {
        final redirectUrl = redirectMatch.group(1)!.replaceAll('&amp;', '&');
        final redirectResponse = await _client
            .get(Uri.parse(redirectUrl))
            .timeout(ApiConfig.timeout);
        return await _handleResponse(redirectResponse);
      }
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data['success'] == true) {
        return data;
      } else {
        throw Exception(data['message'] ?? 'エラーが発生しました');
      }
    } else {
      throw Exception('サーバーエラー: ${response.statusCode}');
    }
  }
}
