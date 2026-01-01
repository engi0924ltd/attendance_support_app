import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

/// マスターGAS用サービス（年度別URL登録用）
class MasterGasService {
  final http.Client _client = http.Client();

  /// 年度別GAS URLをマスターシートに登録
  Future<Map<String, dynamic>> registerYearGasUrl({
    required String facilityId,
    required int fiscalYear,
    required String gasUrl,
    bool setAsActive = false,
  }) async {
    try {
      final url = Uri.parse(ApiConfig.masterUrl);
      final body = jsonEncode({
        'endpoint': 'facility/update-year-gas-url',
        'data': {
          'facilityId': facilityId,
          'fiscalYear': fiscalYear,
          'gasUrl': gasUrl,
          'setAsActive': setAsActive,
        },
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
      throw Exception('年度別GAS URL登録エラー: $e');
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
        return data['data'] ?? data;
      } else {
        throw Exception(data['error'] ?? 'エラーが発生しました');
      }
    } else {
      throw Exception('サーバーエラー: ${response.statusCode}');
    }
  }
}

/// 年度管理サービス
class FiscalYearService {
  final http.Client _client = http.Client();
  final String? facilityGasUrl;

  // SharedPreferencesのキー
  static const String _currentFiscalYearKey = 'current_fiscal_year';

  FiscalYearService({this.facilityGasUrl});

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

  /// 現在選択中の年度を取得
  Future<int> getCurrentFiscalYear() async {
    final prefs = await SharedPreferences.getInstance();
    final savedYear = prefs.getInt(_currentFiscalYearKey);

    if (savedYear != null) {
      return savedYear;
    }

    // 保存されていない場合は、現在の年度を計算（4月始まり）
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;
    return currentMonth >= 4 ? currentYear : currentYear - 1;
  }

  /// 現在選択中の年度を保存
  Future<void> setCurrentFiscalYear(int year) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_currentFiscalYearKey, year);
  }

  /// 利用可能な年度一覧を取得
  Future<Map<String, dynamic>> getAvailableFiscalYears() async {
    try {
      final url = Uri.parse(await _gasUrl);
      final body = jsonEncode({
        'action': 'fiscal-year/get-available',
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
      throw Exception('年度一覧取得エラー: $e');
    }
  }

  /// 次年度シートを作成
  Future<Map<String, dynamic>> createNextFiscalYear(int currentYear) async {
    try {
      final url = Uri.parse(await _gasUrl);
      final body = jsonEncode({
        'action': 'fiscal-year/create-next',
        'currentYear': currentYear,
      });

      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(minutes: 2)); // シート作成は時間がかかる可能性

      return await _handleResponse(response);
    } catch (e) {
      throw Exception('次年度シート作成エラー: $e');
    }
  }

  /// レスポンス処理
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
