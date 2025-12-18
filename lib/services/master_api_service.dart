import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

/// マスタースプレッドシートと通信する基本機能
class MasterApiService {
  final http.Client _client = http.Client();

  /// データを取得する（GET）
  Future<Map<String, dynamic>> get(String endpoint,
      {Map<String, String>? params}) async {
    try {
      final queryParams = {'endpoint': endpoint, ...?params};
      final url =
          Uri.parse(ApiConfig.masterUrl).replace(queryParameters: queryParams);

      final response = await _client.get(url).timeout(ApiConfig.timeout);

      return await _handleResponse(response);
    } catch (e) {
      throw Exception('通信エラー: $e');
    }
  }

  /// データを送信する（POST）
  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    try {
      final url = Uri.parse(ApiConfig.masterUrl);
      final body = jsonEncode({
        'endpoint': endpoint,
        'data': data,
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
      throw Exception('通信エラー: $e');
    }
  }

  /// スプレッドシートからの返事を処理する
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
        throw Exception(data['error'] ?? 'エラーが発生しました');
      }
    } else {
      throw Exception('サーバーエラー: ${response.statusCode}');
    }
  }
}
