import '../models/support_record.dart';
import 'api_service.dart';

/// 支援記録データを扱う機能
class SupportService {
  final ApiService _apiService = ApiService();

  /// 指定日・利用者の支援記録を取得
  Future<SupportRecord?> getSupportRecord(String date, String userName) async {
    final response = await _apiService.get('support/get/$date/$userName');

    if (response['record'] != null) {
      return SupportRecord.fromJson(response['record']);
    }
    return null;
  }

  /// 指定日の支援記録一覧を取得
  Future<List<SupportRecord>> getSupportRecordList(String date) async {
    final response = await _apiService.get('support/list/$date');

    final List<dynamic> records = response['records'] ?? [];

    return records.map((json) => SupportRecord.fromJson(json)).toList();
  }

  /// 支援記録を作成または更新
  Future<Map<String, dynamic>> upsertSupportRecord(
      SupportRecord supportRecord) async {
    final response = await _apiService.post(
      'support/upsert',
      supportRecord.toJson(),
    );
    return response;
  }
}
