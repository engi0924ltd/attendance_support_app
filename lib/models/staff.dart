/// 職員の情報
/// マスタ設定シートのV-AD列に保存される
class Staff {
  final String name;        // V列: 職員名
  final String email;       // X列: メールアドレス（一意キー、ログイン用）
  final String role;        // W列: 権限（「管理者」「従業員」）
  final String? jobType;    // Z列: 職種（自由入力）
  final String? qualification; // AA列: 保有福祉資格
  final String? placement;  // AB列: 職員配置
  final String? employmentType; // AC列: 雇用形態
  final String? retirementDate; // AD列: 退職日
  final String? token;      // ログイン後に受け取る認証トークン
  final String? facilityId; // 所属施設ID
  final String? facilityName; // 所属施設名
  final String? spreadsheetId; // 施設のスプレッドシートID
  final int? rowNumber;     // スプレッドシート上の行番号

  Staff({
    required this.name,
    required this.email,
    required this.role,
    this.jobType,
    this.qualification,
    this.placement,
    this.employmentType,
    this.retirementDate,
    this.token,
    this.facilityId,
    this.facilityName,
    this.spreadsheetId,
    this.rowNumber,
  });

  // スプレッドシートから受け取ったデータを職員情報に変換
  factory Staff.fromJson(Map<String, dynamic> json) {
    return Staff(
      name: (json['name'] ?? json['staffName'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      role: (json['role'] ?? '従業員').toString(),
      jobType: json['jobType']?.toString(),
      qualification: json['qualification']?.toString(),
      placement: json['placement']?.toString(),
      employmentType: json['employmentType']?.toString(),
      retirementDate: json['retirementDate']?.toString(),
      token: json['token']?.toString(),
      facilityId: json['facilityId']?.toString(),
      facilityName: json['facilityName']?.toString(),
      spreadsheetId: json['spreadsheetId']?.toString(),
      rowNumber: json['rowNumber'] is int
          ? json['rowNumber']
          : (json['rowNumber'] != null ? int.tryParse(json['rowNumber'].toString()) : null),
    );
  }

  // 職員情報をスプレッドシートに送る形に変換
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'jobType': jobType,
      'qualification': qualification,
      'placement': placement,
      'employmentType': employmentType,
      'retirementDate': retirementDate,
      'token': token,
      'facilityId': facilityId,
      'facilityName': facilityName,
      'spreadsheetId': spreadsheetId,
      'rowNumber': rowNumber,
    };
  }

  /// 管理者権限を持つか
  bool get isAdmin => role == '管理者';

  /// 従業員権限か
  bool get isEmployee => role == '従業員';

  /// 退職済みか
  bool get isRetired => retirementDate != null && retirementDate!.isNotEmpty;

  /// 権限レベル（1: 管理者、2: 従業員）
  int get permissionLevel => isAdmin ? 1 : 2;

  /// コピーを作成（一部フィールドを変更）
  Staff copyWith({
    String? name,
    String? email,
    String? role,
    String? jobType,
    String? qualification,
    String? placement,
    String? employmentType,
    String? retirementDate,
    String? token,
    String? facilityId,
    String? facilityName,
    String? spreadsheetId,
    int? rowNumber,
  }) {
    return Staff(
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      jobType: jobType ?? this.jobType,
      qualification: qualification ?? this.qualification,
      placement: placement ?? this.placement,
      employmentType: employmentType ?? this.employmentType,
      retirementDate: retirementDate ?? this.retirementDate,
      token: token ?? this.token,
      facilityId: facilityId ?? this.facilityId,
      facilityName: facilityName ?? this.facilityName,
      spreadsheetId: spreadsheetId ?? this.spreadsheetId,
      rowNumber: rowNumber ?? this.rowNumber,
    );
  }
}
