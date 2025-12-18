/// 施設管理者
class FacilityAdmin {
  final String facilityId;
  final String facilityName;
  final String adminName;
  final String email;
  final int permissionLevel; // 固定値: 1
  final String? spreadsheetId;
  final String? fiscalYear;
  final String? gasUrl; // 施設専用のGAS URL
  final String? token;
  final String? timeRounding; // 時間設定（「オン」または「オフ」）

  FacilityAdmin({
    required this.facilityId,
    required this.facilityName,
    required this.adminName,
    required this.email,
    required this.permissionLevel,
    this.spreadsheetId,
    this.fiscalYear,
    this.gasUrl,
    this.token,
    this.timeRounding,
  });

  factory FacilityAdmin.fromJson(Map<String, dynamic> json) {
    return FacilityAdmin(
      facilityId: json['facilityId']?.toString() ?? '',
      facilityName: json['facilityName']?.toString() ?? '',
      adminName: json['adminName']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      permissionLevel: json['permissionLevel'] ?? 1,
      spreadsheetId: json['spreadsheetId']?.toString(),
      fiscalYear: json['fiscalYear']?.toString(),
      gasUrl: json['gasUrl']?.toString(),
      token: json['token']?.toString(),
      timeRounding: json['timeRounding']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'facilityId': facilityId,
      'facilityName': facilityName,
      'adminName': adminName,
      'email': email,
      'permissionLevel': permissionLevel,
      'spreadsheetId': spreadsheetId,
      'fiscalYear': fiscalYear,
      'gasUrl': gasUrl,
      'token': token,
      'timeRounding': timeRounding,
    };
  }
}
