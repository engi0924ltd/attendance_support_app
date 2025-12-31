/// 利用者の情報
/// マスタ設定シートと名簿_2025シートに保存される（全60列対応）
class User {
  // === 基本情報（マスタ設定 A-C列、名簿 B,C,E列）===
  final String name;        // B列: 氏名 ※必須
  final String furigana;    // C列: 氏名カナ ※必須
  final String status;      // E列: ステータス ※必須（「契約中」「退所済み」）

  // === 曜日別出欠予定（マスタ設定のみ D-J列、S列）===
  final String? scheduledMon;  // D列: 出欠（予定）月曜
  final String? scheduledTue;  // E列: 出欠（予定）火曜
  final String? scheduledWed;  // F列: 出欠（予定）水曜
  final String? scheduledThu;  // G列: 出欠（予定）木曜
  final String? scheduledFri;  // H列: 出欠（予定）金曜
  final String? scheduledSat;  // I列: 出欠（予定）土曜
  final String? scheduledSun;  // J列: 出欠（予定）日曜

  // === 連絡先情報（F-L列）===
  final String? mobilePhone;      // F列: 携帯電話番号
  final String? chatworkId;       // G列: ChatWorkルームID
  final String? mail;             // H列: mail
  final String? emergencyContact1; // I列: 緊急連絡先 - 連絡先
  final String? emergencyPhone1;   // J列: 緊急連絡先 - 電話番号
  final String? emergencyContact2; // K列: 緊急連絡先2 - 連絡先
  final String? emergencyPhone2;   // L列: 緊急連絡先2 - 電話番号

  // === 住所情報（M-R列）===
  final String? postalCode;    // M列: 郵便番号
  final String? prefecture;    // N列: 都道府県 ※必須
  final String? city;          // O列: 市区町村 ※必須
  final String? ward;          // P列: 政令指定都市区名入力 ※必須
  final String? address;       // Q列: 住所 ※必須
  final String? address2;      // R列: 住所2（転居先など）

  // === 詳細情報（S-AH列）===
  final String? birthDate;           // S列: 生年月日（西暦）
  final String? lifeProtection;      // T列: 生活保護
  final String? disabilityPension;   // U列: 障がい者手帳年金
  final String? disabilityNumber;    // V列: 障害者手帳番号
  final String? disabilityGrade;     // W列: 障害等級
  final String? disabilityType;      // X列: 障害種別
  final String? handbookValid;       // Y列: 手帳有効期間
  final String? municipalNumber;     // Z列: 市区町村番号
  final String? certificateNumber;   // AA列: 受給者証番号等
  final String? decisionPeriod1;     // AB列: 支給決定期間
  final String? decisionPeriod2;     // AC列: 支給決定期間
  final String? applicableStart;     // AD列: 適用期間開始日
  final String? applicableEnd;       // AE列: 適用期間有効期限
  final String? supplyAmount;        // AF列: 支給量
  final String? supportLevel;        // AG列: 障害支援区分
  final String? useStartDate;        // AH列: 利用開始日 ※必須

  // === 期間計算（AI-AJ列）※自動計算のため入力不要 ===
  // AI列: 本日までの利用期間（自動計算）
  final String? initialAddition;     // AJ列: 初期加算有効期間（30日）

  // === 受給者証情報（AK列）===
  final String? userBurdenLimit;     // AK列: 利用者負担上限月額

  // === 相談支援事業所（AL-AN列）===
  final String? consultationFacility; // AL列: 施設名
  final String? consultationStaff;    // AM列: 担当者名
  final String? consultationContact;  // AN列: 連絡先

  // === グループホーム（AO-AQ列）===
  final String? ghFacility;  // AO列: 施設名
  final String? ghStaff;     // AP列: 担当者名
  final String? ghContact;   // AQ列: 連絡先

  // === その他関係機関（AR-AT列）===
  final String? otherFacility; // AR列: 施設名
  final String? otherStaff;    // AS列: 担当者名
  final String? otherContact;  // AT列: 連絡先

  // === 工賃振込先情報（AU-AY列）===
  final String? bankName;      // AU列: 銀行名
  final String? bankCode;      // AV列: 金融機関コード
  final String? branchName;    // AW列: 支店名
  final String? branchCode;    // AX列: 支店番号
  final String? accountNumber; // AY列: 口座番号

  // === 退所・就労情報（BA-BH列）※退所日入力時のみ表示 ===
  final String? leaveDate;         // BA列: 退所日
  final String? leaveReason;       // BB列: 退所理由
  final String? workName;          // BC列: 勤務先 名称
  final String? workContact;       // BD列: 勤務先 連絡先
  final String? workContent;       // BE列: 業務内容
  final String? contractType;      // BF列: 契約形態（プルダウン）
  final String? employmentSupport; // BG列: 定着支援 有無（プルダウン）
  final String? notes;             // BH列: 配慮事項

  // === スプレッドシート管理用 ===
  final int? rowNumber;       // マスタ設定シート上の行番号
  final int? rosterRowNumber; // 名簿_2025シート上の行番号

  User({
    // 基本情報（必須）
    required this.name,
    required this.furigana,
    required this.status,
    // 曜日別出欠予定
    this.scheduledMon,
    this.scheduledTue,
    this.scheduledWed,
    this.scheduledThu,
    this.scheduledFri,
    this.scheduledSat,
    this.scheduledSun,
    // 連絡先情報
    this.mobilePhone,
    this.chatworkId,
    this.mail,
    this.emergencyContact1,
    this.emergencyPhone1,
    this.emergencyContact2,
    this.emergencyPhone2,
    // 住所情報
    this.postalCode,
    this.prefecture,
    this.city,
    this.ward,
    this.address,
    this.address2,
    // 詳細情報
    this.birthDate,
    this.lifeProtection,
    this.disabilityPension,
    this.disabilityNumber,
    this.disabilityGrade,
    this.disabilityType,
    this.handbookValid,
    this.municipalNumber,
    this.certificateNumber,
    this.decisionPeriod1,
    this.decisionPeriod2,
    this.applicableStart,
    this.applicableEnd,
    this.supplyAmount,
    this.supportLevel,
    this.useStartDate,
    // 期間計算
    this.initialAddition,
    // 受給者証情報
    this.userBurdenLimit,
    // 相談支援事業所
    this.consultationFacility,
    this.consultationStaff,
    this.consultationContact,
    // グループホーム
    this.ghFacility,
    this.ghStaff,
    this.ghContact,
    // その他関係機関
    this.otherFacility,
    this.otherStaff,
    this.otherContact,
    // 工賃振込先情報
    this.bankName,
    this.bankCode,
    this.branchName,
    this.branchCode,
    this.accountNumber,
    // 退所・就労情報
    this.leaveDate,
    this.leaveReason,
    this.workName,
    this.workContact,
    this.workContent,
    this.contractType,
    this.employmentSupport,
    this.notes,
    // 管理用
    this.rowNumber,
    this.rosterRowNumber,
  });

  // スプレッドシートから受け取ったデータを利用者情報に変換
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      // 基本情報
      name: (json['name'] ?? '').toString(),
      furigana: (json['furigana'] ?? '').toString(),
      status: (json['status'] ?? '契約中').toString(),
      // 曜日別出欠予定
      scheduledMon: json['scheduledMon']?.toString(),
      scheduledTue: json['scheduledTue']?.toString(),
      scheduledWed: json['scheduledWed']?.toString(),
      scheduledThu: json['scheduledThu']?.toString(),
      scheduledFri: json['scheduledFri']?.toString(),
      scheduledSat: json['scheduledSat']?.toString(),
      scheduledSun: json['scheduledSun']?.toString(),
      // 連絡先情報
      mobilePhone: json['mobilePhone']?.toString(),
      chatworkId: json['chatworkId']?.toString(),
      mail: json['mail']?.toString(),
      emergencyContact1: json['emergencyContact1']?.toString(),
      emergencyPhone1: json['emergencyPhone1']?.toString(),
      emergencyContact2: json['emergencyContact2']?.toString(),
      emergencyPhone2: json['emergencyPhone2']?.toString(),
      // 住所情報
      postalCode: json['postalCode']?.toString(),
      prefecture: json['prefecture']?.toString(),
      city: json['city']?.toString(),
      ward: json['ward']?.toString(),
      address: json['address']?.toString(),
      address2: json['address2']?.toString(),
      // 詳細情報
      birthDate: json['birthDate']?.toString(),
      lifeProtection: json['lifeProtection']?.toString(),
      disabilityPension: json['disabilityPension']?.toString(),
      disabilityNumber: json['disabilityNumber']?.toString(),
      disabilityGrade: json['disabilityGrade']?.toString(),
      disabilityType: json['disabilityType']?.toString(),
      handbookValid: json['handbookValid']?.toString(),
      municipalNumber: json['municipalNumber']?.toString(),
      certificateNumber: json['certificateNumber']?.toString(),
      decisionPeriod1: json['decisionPeriod1']?.toString(),
      decisionPeriod2: json['decisionPeriod2']?.toString(),
      applicableStart: json['applicableStart']?.toString(),
      applicableEnd: json['applicableEnd']?.toString(),
      supplyAmount: json['supplyAmount']?.toString(),
      supportLevel: json['supportLevel']?.toString(),
      useStartDate: json['useStartDate']?.toString(),
      // 期間計算
      initialAddition: json['initialAddition']?.toString(),
      // 受給者証情報
      userBurdenLimit: json['userBurdenLimit']?.toString(),
      // 相談支援事業所
      consultationFacility: json['consultationFacility']?.toString(),
      consultationStaff: json['consultationStaff']?.toString(),
      consultationContact: json['consultationContact']?.toString(),
      // グループホーム
      ghFacility: json['ghFacility']?.toString(),
      ghStaff: json['ghStaff']?.toString(),
      ghContact: json['ghContact']?.toString(),
      // その他関係機関
      otherFacility: json['otherFacility']?.toString(),
      otherStaff: json['otherStaff']?.toString(),
      otherContact: json['otherContact']?.toString(),
      // 工賃振込先情報
      bankName: json['bankName']?.toString(),
      bankCode: json['bankCode']?.toString(),
      branchName: json['branchName']?.toString(),
      branchCode: json['branchCode']?.toString(),
      accountNumber: json['accountNumber']?.toString(),
      // 退所・就労情報
      leaveDate: json['leaveDate']?.toString(),
      leaveReason: json['leaveReason']?.toString(),
      workName: json['workName']?.toString(),
      workContact: json['workContact']?.toString(),
      workContent: json['workContent']?.toString(),
      contractType: json['contractType']?.toString(),
      employmentSupport: json['employmentSupport']?.toString(),
      notes: json['notes']?.toString(),
      // 管理用
      rowNumber: json['rowNumber'] is int
          ? json['rowNumber']
          : (json['rowNumber'] != null ? int.tryParse(json['rowNumber'].toString()) : null),
      rosterRowNumber: json['rosterRowNumber'] is int
          ? json['rosterRowNumber']
          : (json['rosterRowNumber'] != null ? int.tryParse(json['rosterRowNumber'].toString()) : null),
    );
  }

  // 利用者情報をスプレッドシートに送る形に変換
  Map<String, dynamic> toJson() {
    return {
      // 基本情報
      'name': name,
      'furigana': furigana,
      'status': status,
      // 曜日別出欠予定
      'scheduledMon': scheduledMon,
      'scheduledTue': scheduledTue,
      'scheduledWed': scheduledWed,
      'scheduledThu': scheduledThu,
      'scheduledFri': scheduledFri,
      'scheduledSat': scheduledSat,
      'scheduledSun': scheduledSun,
      // 連絡先情報
      'mobilePhone': mobilePhone,
      'chatworkId': chatworkId,
      'mail': mail,
      'emergencyContact1': emergencyContact1,
      'emergencyPhone1': emergencyPhone1,
      'emergencyContact2': emergencyContact2,
      'emergencyPhone2': emergencyPhone2,
      // 住所情報
      'postalCode': postalCode,
      'prefecture': prefecture,
      'city': city,
      'ward': ward,
      'address': address,
      'address2': address2,
      // 詳細情報
      'birthDate': birthDate,
      'lifeProtection': lifeProtection,
      'disabilityPension': disabilityPension,
      'disabilityNumber': disabilityNumber,
      'disabilityGrade': disabilityGrade,
      'disabilityType': disabilityType,
      'handbookValid': handbookValid,
      'municipalNumber': municipalNumber,
      'certificateNumber': certificateNumber,
      'decisionPeriod1': decisionPeriod1,
      'decisionPeriod2': decisionPeriod2,
      'applicableStart': applicableStart,
      'applicableEnd': applicableEnd,
      'supplyAmount': supplyAmount,
      'supportLevel': supportLevel,
      'useStartDate': useStartDate,
      // 期間計算
      'initialAddition': initialAddition,
      // 受給者証情報
      'userBurdenLimit': userBurdenLimit,
      // 相談支援事業所
      'consultationFacility': consultationFacility,
      'consultationStaff': consultationStaff,
      'consultationContact': consultationContact,
      // グループホーム
      'ghFacility': ghFacility,
      'ghStaff': ghStaff,
      'ghContact': ghContact,
      // その他関係機関
      'otherFacility': otherFacility,
      'otherStaff': otherStaff,
      'otherContact': otherContact,
      // 工賃振込先情報
      'bankName': bankName,
      'bankCode': bankCode,
      'branchName': branchName,
      'branchCode': branchCode,
      'accountNumber': accountNumber,
      // 退所・就労情報
      'leaveDate': leaveDate,
      'leaveReason': leaveReason,
      'workName': workName,
      'workContact': workContact,
      'workContent': workContent,
      'contractType': contractType,
      'employmentSupport': employmentSupport,
      'notes': notes,
      // 管理用
      'rowNumber': rowNumber,
      'rosterRowNumber': rosterRowNumber,
    };
  }

  /// 契約中か
  bool get isActive => status == '契約中';

  /// 退所済みか
  bool get isInactive => status == '退所済み';

  /// 曜日別予定をMapで取得
  Map<String, String?> get weeklySchedule => {
    '月': scheduledMon,
    '火': scheduledTue,
    '水': scheduledWed,
    '木': scheduledThu,
    '金': scheduledFri,
    '土': scheduledSat,
    '日': scheduledSun,
  };

  /// コピーを作成（一部フィールドを変更）
  User copyWith({
    String? name,
    String? furigana,
    String? status,
    String? scheduledMon,
    String? scheduledTue,
    String? scheduledWed,
    String? scheduledThu,
    String? scheduledFri,
    String? scheduledSat,
    String? scheduledSun,
    String? mobilePhone,
    String? chatworkId,
    String? mail,
    String? emergencyContact1,
    String? emergencyPhone1,
    String? emergencyContact2,
    String? emergencyPhone2,
    String? postalCode,
    String? prefecture,
    String? city,
    String? ward,
    String? address,
    String? address2,
    String? birthDate,
    String? lifeProtection,
    String? disabilityPension,
    String? disabilityNumber,
    String? disabilityGrade,
    String? disabilityType,
    String? handbookValid,
    String? municipalNumber,
    String? certificateNumber,
    String? decisionPeriod1,
    String? decisionPeriod2,
    String? applicableStart,
    String? applicableEnd,
    String? supplyAmount,
    String? supportLevel,
    String? useStartDate,
    String? initialAddition,
    String? userBurdenLimit,
    String? consultationFacility,
    String? consultationStaff,
    String? consultationContact,
    String? ghFacility,
    String? ghStaff,
    String? ghContact,
    String? otherFacility,
    String? otherStaff,
    String? otherContact,
    String? bankName,
    String? bankCode,
    String? branchName,
    String? branchCode,
    String? accountNumber,
    String? leaveDate,
    String? leaveReason,
    String? workName,
    String? workContact,
    String? workContent,
    String? contractType,
    String? employmentSupport,
    String? notes,
    int? rowNumber,
    int? rosterRowNumber,
  }) {
    return User(
      name: name ?? this.name,
      furigana: furigana ?? this.furigana,
      status: status ?? this.status,
      scheduledMon: scheduledMon ?? this.scheduledMon,
      scheduledTue: scheduledTue ?? this.scheduledTue,
      scheduledWed: scheduledWed ?? this.scheduledWed,
      scheduledThu: scheduledThu ?? this.scheduledThu,
      scheduledFri: scheduledFri ?? this.scheduledFri,
      scheduledSat: scheduledSat ?? this.scheduledSat,
      scheduledSun: scheduledSun ?? this.scheduledSun,
      mobilePhone: mobilePhone ?? this.mobilePhone,
      chatworkId: chatworkId ?? this.chatworkId,
      mail: mail ?? this.mail,
      emergencyContact1: emergencyContact1 ?? this.emergencyContact1,
      emergencyPhone1: emergencyPhone1 ?? this.emergencyPhone1,
      emergencyContact2: emergencyContact2 ?? this.emergencyContact2,
      emergencyPhone2: emergencyPhone2 ?? this.emergencyPhone2,
      postalCode: postalCode ?? this.postalCode,
      prefecture: prefecture ?? this.prefecture,
      city: city ?? this.city,
      ward: ward ?? this.ward,
      address: address ?? this.address,
      address2: address2 ?? this.address2,
      birthDate: birthDate ?? this.birthDate,
      lifeProtection: lifeProtection ?? this.lifeProtection,
      disabilityPension: disabilityPension ?? this.disabilityPension,
      disabilityNumber: disabilityNumber ?? this.disabilityNumber,
      disabilityGrade: disabilityGrade ?? this.disabilityGrade,
      disabilityType: disabilityType ?? this.disabilityType,
      handbookValid: handbookValid ?? this.handbookValid,
      municipalNumber: municipalNumber ?? this.municipalNumber,
      certificateNumber: certificateNumber ?? this.certificateNumber,
      decisionPeriod1: decisionPeriod1 ?? this.decisionPeriod1,
      decisionPeriod2: decisionPeriod2 ?? this.decisionPeriod2,
      applicableStart: applicableStart ?? this.applicableStart,
      applicableEnd: applicableEnd ?? this.applicableEnd,
      supplyAmount: supplyAmount ?? this.supplyAmount,
      supportLevel: supportLevel ?? this.supportLevel,
      useStartDate: useStartDate ?? this.useStartDate,
      initialAddition: initialAddition ?? this.initialAddition,
      userBurdenLimit: userBurdenLimit ?? this.userBurdenLimit,
      consultationFacility: consultationFacility ?? this.consultationFacility,
      consultationStaff: consultationStaff ?? this.consultationStaff,
      consultationContact: consultationContact ?? this.consultationContact,
      ghFacility: ghFacility ?? this.ghFacility,
      ghStaff: ghStaff ?? this.ghStaff,
      ghContact: ghContact ?? this.ghContact,
      otherFacility: otherFacility ?? this.otherFacility,
      otherStaff: otherStaff ?? this.otherStaff,
      otherContact: otherContact ?? this.otherContact,
      bankName: bankName ?? this.bankName,
      bankCode: bankCode ?? this.bankCode,
      branchName: branchName ?? this.branchName,
      branchCode: branchCode ?? this.branchCode,
      accountNumber: accountNumber ?? this.accountNumber,
      leaveDate: leaveDate ?? this.leaveDate,
      leaveReason: leaveReason ?? this.leaveReason,
      workName: workName ?? this.workName,
      workContact: workContact ?? this.workContact,
      workContent: workContent ?? this.workContent,
      contractType: contractType ?? this.contractType,
      employmentSupport: employmentSupport ?? this.employmentSupport,
      notes: notes ?? this.notes,
      rowNumber: rowNumber ?? this.rowNumber,
      rosterRowNumber: rosterRowNumber ?? this.rosterRowNumber,
    );
  }
}
