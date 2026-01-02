import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

/// 請求業務用プルダウン選択肢
class BillingDropdowns {
  final List<String> type; // 種別
  final List<String> wageCategory; // 平均工賃月額区分
  final List<String> regionCategory; // 地域区分
  final List<String> welfareStaffAddition; // 福祉専門職員配置等加算
  final List<String> transportAddition; // 送迎加算種類
  final List<String> welfareImprovement; // 福祉介護職員等処遇改善加算

  BillingDropdowns({
    required this.type,
    required this.wageCategory,
    required this.regionCategory,
    required this.welfareStaffAddition,
    required this.transportAddition,
    required this.welfareImprovement,
  });

  factory BillingDropdowns.fromJson(Map<String, dynamic> json) {
    return BillingDropdowns(
      type: List<String>.from(json['type'] ?? []),
      wageCategory: List<String>.from(json['wageCategory'] ?? []),
      regionCategory: List<String>.from(json['regionCategory'] ?? []),
      welfareStaffAddition: List<String>.from(json['welfareStaffAddition'] ?? []),
      transportAddition: List<String>.from(json['transportAddition'] ?? []),
      welfareImprovement: List<String>.from(json['welfareImprovement'] ?? []),
    );
  }

  /// デフォルト値（API取得失敗時のフォールバック）
  factory BillingDropdowns.defaultValues() {
    return BillingDropdowns(
      type: ['就継B I', '就継B II', '就継B III', '就継B IV', '就継B V', '就継B VI', '基準該当就継B'],
      wageCategory: ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10'],
      regionCategory: ['一級地', '二級地', '三級地', '四級地', '五級地', '六級地', '七級地', 'その他'],
      welfareStaffAddition: ['10', '20', '30'],
      transportAddition: ['1', '21'],
      welfareImprovement: ['1', '2', '3', '4'],
    );
  }
}

/// 月別利用者（請求対象）
class MonthlyUser {
  final String name;
  final String furigana;
  final bool isDeparted; // 当月退所者かどうか

  MonthlyUser({
    required this.name,
    required this.furigana,
    this.isDeparted = false,
  });
}

/// 請求業務サービス
class BillingService {
  final http.Client _client = http.Client();
  final String? facilityGasUrl;

  BillingService({this.facilityGasUrl});

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

  /// 請求業務用プルダウン選択肢を取得
  Future<BillingDropdowns> getBillingDropdowns() async {
    try {
      final url = Uri.parse(await _gasUrl);
      final body = jsonEncode({
        'action': 'billing/get-dropdowns',
      });

      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(ApiConfig.timeout);

      final data = await _handleResponse(response);
      return BillingDropdowns.fromJson(data);
    } catch (e) {
      // エラー時はデフォルト値を返す
      return BillingDropdowns.defaultValues();
    }
  }

  /// 請求設定を保存
  Future<bool> saveBillingSettings(Map<String, dynamic> settings) async {
    try {
      final url = Uri.parse(await _gasUrl);
      final body = jsonEncode({
        'action': 'billing/save-settings',
        'settings': settings,
      });

      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(ApiConfig.timeout);

      await _handleResponse(response);
      return true;
    } catch (e) {
      rethrow;
    }
  }

  /// 請求設定を取得
  Future<Map<String, dynamic>> getBillingSettings() async {
    try {
      final url = Uri.parse(await _gasUrl);
      final body = jsonEncode({
        'action': 'billing/get-settings',
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
      // エラー時は空のMapを返す
      return {};
    }
  }

  /// 市町村一覧を取得
  Future<List<Map<String, String>>> getMunicipalities() async {
    try {
      final url = Uri.parse(await _gasUrl);
      final body = jsonEncode({
        'action': 'municipality/get',
      });

      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(ApiConfig.timeout);

      final data = await _handleResponse(response);
      final municipalities = data['municipalities'] as List<dynamic>? ?? [];
      return municipalities
          .map((m) => {
                'name': (m['name'] ?? '').toString(),
                'code': (m['code'] ?? '').toString(),
              })
          .toList();
    } catch (e) {
      // エラー時は空のリストを返す
      return [];
    }
  }

  /// 市町村を追加
  Future<void> addMunicipality(String name, String code) async {
    try {
      final url = Uri.parse(await _gasUrl);
      final body = jsonEncode({
        'action': 'municipality/add',
        'name': name,
        'code': code,
      });

      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(ApiConfig.timeout);

      await _handleResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  /// 市町村を削除
  Future<void> deleteMunicipality(int index) async {
    try {
      final url = Uri.parse(await _gasUrl);
      final body = jsonEncode({
        'action': 'municipality/delete',
        'index': index,
      });

      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(ApiConfig.timeout);

      await _handleResponse(response);
    } catch (e) {
      rethrow;
    }
  }

  /// 指定月の利用者一覧を取得（統計・分析と同じロジック）
  Future<List<MonthlyUser>> getMonthlyUsers(String yearMonth) async {
    try {
      final url = Uri.parse(await _gasUrl);
      final body = jsonEncode({
        'action': 'billing/get-monthly-users',
        'yearMonth': yearMonth,
      });

      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(ApiConfig.timeout);

      final data = await _handleResponse(response);
      final users = data['users'] as List<dynamic>? ?? [];
      return users
          .map((u) => MonthlyUser(
                name: (u['name'] ?? '').toString(),
                furigana: (u['furigana'] ?? '').toString(),
                isDeparted: u['isDeparted'] == true,
              ))
          .toList();
    } catch (e) {
      // エラー時は空のリストを返す
      return [];
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
        throw Exception(data['message'] ?? 'エラーが発生しました');
      }
    } else {
      throw Exception('サーバーエラー: ${response.statusCode}');
    }
  }
}
