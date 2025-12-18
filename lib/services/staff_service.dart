import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/staff.dart';

/// 職員（支援者）管理サービス
class StaffService {
  final http.Client _client = http.Client();
  final String? facilityGasUrl; // 施設固有のGAS URL

  StaffService({this.facilityGasUrl});

  /// 使用するGAS URLを取得（施設固有 > 保存済み > デフォルト）
  Future<String> get _gasUrl async {
    // コンストラクタで指定されたURLを優先
    if (facilityGasUrl != null && facilityGasUrl!.isNotEmpty) {
      return facilityGasUrl!;
    }

    // 保存された施設のURLを次に優先
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('facility_gas_url');
    if (savedUrl != null && savedUrl.isNotEmpty) {
      return savedUrl;
    }

    // デフォルトURL
    return ApiConfig.baseUrl;
  }

  /// 職員一覧を取得
  Future<List<Staff>> getStaffList() async {
    try {
      final url = Uri.parse('${await _gasUrl}?action=staff/list');
      final response = await _client.get(url).timeout(ApiConfig.timeout);

      final data = await _handleResponse(response);

      if (data['success'] == true && data['staffList'] != null) {
        final List<dynamic> staffListData = data['staffList'];
        return staffListData.map((json) => Staff.fromJson(json)).toList();
      }

      return [];
    } catch (e) {
      throw Exception('職員一覧取得エラー: $e');
    }
  }

  /// 職員を新規登録
  Future<Map<String, dynamic>> createStaff({
    required String name,
    required String email,
    required String password,
    required String role, // 「管理者」「従業員」
    String? jobType,
  }) async {
    try {
      final url = Uri.parse(await _gasUrl);
      final body = jsonEncode({
        'action': 'staff/create',
        'name': name,
        'email': email,
        'password': password,
        'role': role,
        'jobType': jobType,
      });

      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(ApiConfig.timeout);

      return await _handleResponse(response);
    } catch (e) {
      throw Exception('職員登録エラー: $e');
    }
  }

  /// 職員情報を更新
  Future<Map<String, dynamic>> updateStaff({
    required int rowNumber,
    required String name,
    required String email,
    required String role,
    String? password, // パスワードは任意（変更時のみ）
    String? jobType,
  }) async {
    try {
      final url = Uri.parse(await _gasUrl);
      final body = jsonEncode({
        'action': 'staff/update',
        'rowNumber': rowNumber,
        'name': name,
        'email': email,
        'role': role,
        if (password != null && password.isNotEmpty) 'password': password,
        'jobType': jobType,
      });

      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(ApiConfig.timeout);

      return await _handleResponse(response);
    } catch (e) {
      throw Exception('職員更新エラー: $e');
    }
  }

  /// 職員を削除
  Future<Map<String, dynamic>> deleteStaff(int rowNumber) async {
    try {
      final url = Uri.parse(await _gasUrl);
      final body = jsonEncode({
        'action': 'staff/delete',
        'rowNumber': rowNumber,
      });

      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(ApiConfig.timeout);

      return await _handleResponse(response);
    } catch (e) {
      throw Exception('職員削除エラー: $e');
    }
  }

  /// レスポンス処理
  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    // 302リダイレクトの場合、リダイレクト先を手動でフォロー
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
