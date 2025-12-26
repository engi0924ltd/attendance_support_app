import '../models/facility.dart';
import 'master_api_service.dart';

/// 施設管理サービス
class FacilityService {
  final MasterApiService _apiService = MasterApiService();

  /// 全施設一覧を取得
  Future<List<Facility>> getAllFacilities() async {
    final response = await _apiService.get('facilities');

    final List<dynamic> facilities = response['data']['facilities'] ?? [];
    return facilities.map((json) => Facility.fromJson(json)).toList();
  }

  /// 特定施設の情報を取得
  Future<Facility> getFacility(String facilityId) async {
    final response =
        await _apiService.get('facility', params: {'facilityId': facilityId});

    final facilityData = response['data']['facility'];
    return Facility.fromJson(facilityData);
  }

  /// 新規施設を登録
  Future<Map<String, dynamic>> createFacility(
      Map<String, dynamic> facilityData) async {
    final response = await _apiService.post('facility/create', facilityData);
    return response;
  }

  /// 施設情報を更新
  Future<Map<String, dynamic>> updateFacility(
      String facilityId, Map<String, dynamic> facilityData) async {
    final response = await _apiService.post('facility/update', {
      'facilityId': facilityId,
      ...facilityData,
    });
    return response;
  }

  /// 施設を削除（論理削除）
  Future<Map<String, dynamic>> deleteFacility(String facilityId) async {
    final response = await _apiService.post('facility/delete', {
      'facilityId': facilityId,
    });
    return response;
  }

  /// 施設のGAS URLを更新
  Future<Map<String, dynamic>> updateFacilityGasUrl(
      String facilityId, String gasUrl) async {
    final response = await _apiService.post('facility/update-gas-url', {
      'facilityId': facilityId,
      'gasUrl': gasUrl,
    });
    return response;
  }

  /// 施設のChatWork APIキーを更新
  Future<Map<String, dynamic>> updateChatworkApiKey(
      String facilityId, String apiKey) async {
    final response = await _apiService.post('facility/update-chatwork-api-key', {
      'facilityId': facilityId,
      'chatworkApiKey': apiKey,
    });
    return response;
  }
}
