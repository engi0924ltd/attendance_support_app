/// 施設情報
class Facility {
  final String facilityId;
  final String facilityName;
  final String adminName;
  final String adminEmail;
  final String? spreadsheetId;
  final String? fiscalYear;
  final String? gasUrl; // 施設専用のGAS URL
  final String? driveFolderId;
  final String? address;
  final String? phone;
  final String status;
  final String? timeRounding; // 時間設定（「オン」または「オフ」）
  final String? facilityCode; // 施設コード（6桁数字、複数PC設定用）
  final String? facilityPassword; // 施設パスワード（8桁英数字、複数PC設定用）
  final String? chatworkApiKey; // ChatWork APIキー

  Facility({
    required this.facilityId,
    required this.facilityName,
    required this.adminName,
    required this.adminEmail,
    this.spreadsheetId,
    this.fiscalYear,
    this.gasUrl,
    this.driveFolderId,
    this.address,
    this.phone,
    required this.status,
    this.timeRounding,
    this.facilityCode,
    this.facilityPassword,
    this.chatworkApiKey,
  });

  factory Facility.fromJson(Map<String, dynamic> json) {
    return Facility(
      facilityId: json['facilityId']?.toString() ?? '',
      facilityName: json['facilityName']?.toString() ?? '',
      adminName: json['adminName']?.toString() ?? '',
      adminEmail: json['adminEmail']?.toString() ?? '',
      spreadsheetId: json['spreadsheetId']?.toString(),
      fiscalYear: json['fiscalYear']?.toString(),
      gasUrl: json['gasUrl']?.toString(),
      driveFolderId: json['driveFolderId']?.toString(),
      address: json['address']?.toString(),
      phone: json['phone']?.toString(),
      status: json['status']?.toString() ?? '有効',
      timeRounding: json['timeRounding']?.toString(),
      facilityCode: json['facilityCode']?.toString(),
      facilityPassword: json['facilityPassword']?.toString(),
      chatworkApiKey: json['chatworkApiKey']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'facilityId': facilityId,
      'facilityName': facilityName,
      'adminName': adminName,
      'adminEmail': adminEmail,
      'spreadsheetId': spreadsheetId,
      'fiscalYear': fiscalYear,
      'gasUrl': gasUrl,
      'driveFolderId': driveFolderId,
      'address': address,
      'phone': phone,
      'status': status,
      'timeRounding': timeRounding,
      'facilityCode': facilityCode,
      'facilityPassword': facilityPassword,
      'chatworkApiKey': chatworkApiKey,
    };
  }

  /// セットアップが完了しているか（GAS URLが設定済みか）
  bool get isSetupComplete => gasUrl != null && gasUrl!.isNotEmpty;
}
