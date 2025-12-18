import 'package:shared_preferences/shared_preferences.dart';
import '../models/staff.dart';
import 'api_service.dart';

/// ログイン機能
class AuthService {
  final ApiService _apiService = ApiService();

  /// 職員がログインする
  Future<Staff> staffLogin(String email, String password) async {
    final response = await _apiService.post('auth/staff/login', {
      'email': email,
      'password': password,
    });

    final staff = Staff.fromJson(response);

    // ログイン情報を保存
    await _saveStaffToken(staff.token ?? '');
    await _saveStaffName(staff.name);

    return staff;
  }

  /// ログイン認証情報を保存する（ログイン保持用）
  Future<void> saveLoginCredentials(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_email', email);
    await prefs.setString('saved_password', password);
    await prefs.setBool('remember_me', true);
  }

  /// 保存されたログイン認証情報を取得する
  Future<Map<String, String>?> getSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? false;

    if (!rememberMe) {
      return null;
    }

    final email = prefs.getString('saved_email');
    final password = prefs.getString('saved_password');

    if (email != null && password != null) {
      return {'email': email, 'password': password};
    }

    return null;
  }

  /// ログイン認証情報をクリアする
  Future<void> clearLoginCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_email');
    await prefs.remove('saved_password');
    await prefs.setBool('remember_me', false);
  }

  /// ログイン情報を保存する
  Future<void> _saveStaffToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('staff_token', token);
  }

  /// 職員名を保存する
  Future<void> _saveStaffName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('staff_name', name);
  }

  /// 保存されているログイン情報を取得
  Future<String?> getStaffToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('staff_token');
  }

  /// 保存されている職員名を取得
  Future<String?> getStaffName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('staff_name');
  }

  /// ログアウトする
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('staff_token');
    await prefs.remove('staff_name');
  }

  /// ログイン済みかチェック
  Future<bool> isLoggedIn() async {
    final token = await getStaffToken();
    return token != null && token.isNotEmpty;
  }
}
