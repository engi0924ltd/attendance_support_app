import 'package:shared_preferences/shared_preferences.dart';
import '../models/super_admin.dart';
import '../models/admin_login_result.dart';
import 'master_api_service.dart';

/// 全権管理者（スーパー管理者）の認証機能
class MasterAuthService {
  final MasterApiService _apiService = MasterApiService();

  /// 統合管理者ログイン（全権管理者 or 施設管理者）
  Future<AdminLoginResult> unifiedAdminLogin(
      String email, String password) async {
    final response = await _apiService.post('auth/admin/login', {
      'email': email,
      'password': password,
    });

    final adminData = response['data'];
    return AdminLoginResult.fromJson(adminData);
  }

  /// 全権管理者ログイン（旧メソッド、後方互換性のため残す）
  Future<SuperAdmin> superAdminLogin(String email, String password) async {
    final response = await _apiService.post('auth/superadmin/login', {
      'email': email,
      'password': password,
    });

    final adminData = response['data'];
    return SuperAdmin.fromJson(adminData);
  }

  /// 施設コード + 施設パスワードで施設情報を取得（複数PC設定用）
  Future<Map<String, dynamic>> getFacilityByCode(
      String facilityCode, String facilityPassword) async {
    final response = await _apiService.post('facility/get-by-code', {
      'facilityCode': facilityCode,
      'facilityPassword': facilityPassword,
    });

    final facilityData = response['data'];

    // GAS URLを自動保存（空でない場合のみ）
    if (facilityData['gasUrl'] != null &&
        facilityData['gasUrl'].toString().isNotEmpty) {
      await saveFacilityGasUrl(facilityData['gasUrl']);
    }

    // 時間設定も保存
    if (facilityData['timeRounding'] != null) {
      await saveFacilityTimeRounding(facilityData['timeRounding']);
    }

    return facilityData;
  }

  /// ログイン情報を保存
  Future<void> saveLoginCredentials(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('super_admin_email', email);
    await prefs.setString('super_admin_password', password);
    await prefs.setBool('super_admin_remember', true);
  }

  /// 保存されたログイン情報を取得
  Future<Map<String, String>?> getSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('super_admin_remember') ?? false;

    if (!rememberMe) return null;

    final email = prefs.getString('super_admin_email');
    final password = prefs.getString('super_admin_password');

    if (email != null && password != null) {
      return {
        'email': email,
        'password': password,
      };
    }

    return null;
  }

  /// ログイン情報をクリア
  Future<void> clearLoginCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('super_admin_email');
    await prefs.remove('super_admin_password');
    await prefs.remove('super_admin_remember');
  }

  /// ログアウト（認証情報もクリア）
  Future<void> logout() async {
    await clearLoginCredentials();
    await clearFacilityGasUrl();
    await clearFacilityTimeRounding();
  }

  /// セッションのみログアウト（認証情報・施設情報は維持）
  /// 施設コードで設定した施設情報（GAS URL等）は保持し、再ログイン時に施設コード入力不要にする
  Future<void> logoutSession() async {
    // 施設情報（facility_gas_url, facility_time_rounding）は維持する
    // 完全ログアウト（logout()）の場合のみ施設情報をクリアする
  }

  /// 施設のGAS URLを保存
  Future<void> saveFacilityGasUrl(String gasUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('facility_gas_url', gasUrl);
  }

  /// 保存された施設のGAS URLを取得
  Future<String?> getFacilityGasUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('facility_gas_url');
  }

  /// 施設のGAS URLをクリア
  Future<void> clearFacilityGasUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('facility_gas_url');
  }

  /// 施設の時間設定を保存
  Future<void> saveFacilityTimeRounding(String timeRounding) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('facility_time_rounding', timeRounding);
  }

  /// 保存された施設の時間設定を取得
  Future<String?> getFacilityTimeRounding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('facility_time_rounding');
  }

  /// 施設の時間設定をクリア
  Future<void> clearFacilityTimeRounding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('facility_time_rounding');
  }
}
