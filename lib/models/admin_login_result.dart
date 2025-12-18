import 'super_admin.dart';
import 'facility_admin.dart';

/// 管理者ログイン結果
class AdminLoginResult {
  final String accountType; // 'super_admin' or 'facility_admin'
  final SuperAdmin? superAdmin;
  final FacilityAdmin? facilityAdmin;

  AdminLoginResult({
    required this.accountType,
    this.superAdmin,
    this.facilityAdmin,
  });

  bool isSuperAdmin() => accountType == 'super_admin';
  bool isFacilityAdmin() => accountType == 'facility_admin';

  factory AdminLoginResult.fromJson(Map<String, dynamic> json) {
    final accountType = json['accountType']?.toString() ?? '';

    if (accountType == 'super_admin') {
      return AdminLoginResult(
        accountType: accountType,
        superAdmin: SuperAdmin.fromJson(json),
      );
    } else if (accountType == 'facility_admin') {
      return AdminLoginResult(
        accountType: accountType,
        facilityAdmin: FacilityAdmin.fromJson(json),
      );
    } else {
      throw Exception('不明なアカウントタイプ: $accountType');
    }
  }
}
