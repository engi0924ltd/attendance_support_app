import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

/// スプレッドシートと通信する基本機能
class ApiService {
  // HTTPクライアント（リダイレクトを自動フォロー）
  final http.Client _client = http.Client();
  final String? facilityGasUrl; // 施設固有のGAS URL

  ApiService({this.facilityGasUrl});

  /// 使用するGAS URLを取得（施設固有 > デフォルト）
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

  /// データを取得する（GET）
  Future<Map<String, dynamic>> get(String endpoint) async {
    final stopwatch = Stopwatch()..start();
    try {
      print('⏱️ [API-GET] 開始: $endpoint');

      final baseUrl = await _gasUrl;
      final url = Uri.parse('$baseUrl?action=$endpoint');

      final requestStart = Stopwatch()..start();
      final response = await _client.get(url).timeout(ApiConfig.timeout);
      requestStart.stop();

      print('⏱️ [API-GET] ネットワーク時間: ${requestStart.elapsedMilliseconds}ms');

      final result = await _handleResponse(response);

      stopwatch.stop();
      print('⏱️ [API-GET] 完了: $endpoint (合計: ${stopwatch.elapsedMilliseconds}ms)');

      return result;
    } catch (e) {
      stopwatch.stop();
      print('❌ [API-GET] エラー: $endpoint (${stopwatch.elapsedMilliseconds}ms) - $e');
      throw Exception('通信エラー: $e');
    }
  }

  /// データを送信する（POST）
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      print('⏱️ [API-POST] 開始: $endpoint');

      final baseUrl = await _gasUrl;
      final url = Uri.parse(baseUrl);
      final body = jsonEncode({
        'action': endpoint,
        ...data,
      });

      final requestStart = Stopwatch()..start();
      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(ApiConfig.timeout);
      requestStart.stop();

      print('⏱️ [API-POST] ネットワーク時間: ${requestStart.elapsedMilliseconds}ms');

      final result = await _handleResponse(response);

      stopwatch.stop();
      print('⏱️ [API-POST] 完了: $endpoint (合計: ${stopwatch.elapsedMilliseconds}ms)');

      return result;
    } catch (e) {
      stopwatch.stop();
      print('❌ [API-POST] エラー: $endpoint (${stopwatch.elapsedMilliseconds}ms) - $e');
      throw Exception('通信エラー: $e');
    }
  }

  /// データを更新する（PUT）
  Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    try {
      final baseUrl = await _gasUrl;
      final url = Uri.parse(baseUrl);
      final body = jsonEncode({
        'action': endpoint,
        ...data,
      });

      final response = await _client
          .put(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(ApiConfig.timeout);

      return await _handleResponse(response);
    } catch (e) {
      throw Exception('通信エラー: $e');
    }
  }

  /// スプレッドシートからの返事を処理する
  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    // 302リダイレクトの場合、リダイレクト先を手動でフォロー
    if (response.statusCode == 302) {
      print('🔄 [REDIRECT] 302リダイレクト検出');
      final redirectStart = Stopwatch()..start();

      // HTMLからリダイレクトURLを抽出
      final redirectMatch = RegExp(r'HREF="([^"]+)"').firstMatch(response.body);

      if (redirectMatch != null) {
        final redirectUrl = redirectMatch.group(1)!.replaceAll('&amp;', '&');

        print('🔄 [REDIRECT] リダイレクト先へ再リクエスト');
        // リダイレクト先にGETリクエストを送る
        final redirectResponse = await _client.get(Uri.parse(redirectUrl)).timeout(ApiConfig.timeout);

        redirectStart.stop();
        print('🔄 [REDIRECT] 完了: ${redirectStart.elapsedMilliseconds}ms');

        // リダイレクト先のレスポンスを処理
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
