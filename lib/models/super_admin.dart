/// 全施設管理者（スーパー管理者）
class SuperAdmin {
  final String adminId;
  final String adminName;
  final String email;
  final int permissionLevel; // 固定値: 0
  final String? token;

  SuperAdmin({
    required this.adminId,
    required this.adminName,
    required this.email,
    required this.permissionLevel,
    this.token,
  });

  factory SuperAdmin.fromJson(Map<String, dynamic> json) {
    return SuperAdmin(
      adminId: json['adminId']?.toString() ?? '',
      adminName: json['adminName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      permissionLevel: json['permissionLevel'] ?? 0,
      token: json['token']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'adminId': adminId,
      'adminName': adminName,
      'email': email,
      'permissionLevel': permissionLevel,
      'token': token,
    };
  }
}
