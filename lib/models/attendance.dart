/// 勤怠データ（出勤・退勤などの記録）
class Attendance {
  final int? rowId;                 // スプレッドシートの行番号
  final String date;                // 日時（D列）
  final String userName;            // 利用者名（E列）
  final String? scheduledUse;       // 利用予定（F列）
  final String? attendanceStatus;   // 出欠（内容）（G列）
  final String? morningTask;        // 担当業務 AM（H列）
  final String? afternoonTask;      // 担当業務 PM（I列）
  final String? healthCondition;    // 本日の体調（K列）
  final String? sleepStatus;        // 睡眠状況（L列）
  final String? checkinComment;     // 出勤時利用者コメント（M列）
  final String? fatigue;            // 疲労感（N列）
  final String? stress;             // 心理的負荷（O列）
  final String? checkoutComment;    // 退勤時利用者コメント（P列）
  final String? checkinTime;        // 出勤時間（S列）
  final String? checkoutTime;       // 退社時間（T列）
  final String? lunchBreak;         // 昼休憩（U列）
  final String? shortBreak;         // 15分休（W列）
  final String? otherBreak;         // 他休憩（Y列）
  final int? actualWorkMinutes;     // 実労時間（Z列、分単位）
  final bool mealService;           // 食事提供加算（AC列）
  final bool absenceSupport;        // 欠席対応加算（AD列）
  final bool visitSupport;          // 訪問支援加算（AE列）
  final bool transportService;      // 送迎加算（AF列）
  final String? userStatus;         // 本人の状況（Z列：支援記録）

  Attendance({
    this.rowId,
    required this.date,
    required this.userName,
    this.scheduledUse,
    this.attendanceStatus,
    this.morningTask,
    this.afternoonTask,
    this.healthCondition,
    this.sleepStatus,
    this.checkinComment,
    this.fatigue,
    this.stress,
    this.checkoutComment,
    this.checkinTime,
    this.checkoutTime,
    this.lunchBreak,
    this.shortBreak,
    this.otherBreak,
    this.actualWorkMinutes,
    this.mealService = false,
    this.absenceSupport = false,
    this.visitSupport = false,
    this.transportService = false,
    this.userStatus,
  });

  // スプレッドシートから受け取ったデータを勤怠データに変換
  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      rowId: json['rowId'],
      date: json['date']?.toString() ?? '',
      userName: json['userName']?.toString() ?? '',
      scheduledUse: json['scheduledUse']?.toString(),
      attendanceStatus: json['attendance']?.toString(),
      morningTask: json['morningTask']?.toString(),
      afternoonTask: json['afternoonTask']?.toString(),
      healthCondition: json['healthCondition']?.toString(),
      sleepStatus: json['sleepStatus']?.toString(),
      checkinComment: json['checkinComment']?.toString(),
      fatigue: json['fatigue']?.toString(),
      stress: json['stress']?.toString(),
      checkoutComment: json['checkoutComment']?.toString(),
      checkinTime: json['checkinTime']?.toString(),
      checkoutTime: json['checkoutTime']?.toString(),
      lunchBreak: json['lunchBreak']?.toString(),
      shortBreak: json['shortBreak']?.toString(),
      otherBreak: json['otherBreak']?.toString(),
      actualWorkMinutes: json['actualWorkMinutes'],
      mealService: json['mealService'] ?? false,
      absenceSupport: json['absenceSupport'] ?? false,
      visitSupport: json['visitSupport'] ?? false,
      transportService: json['transportService'] ?? false,
      userStatus: json['userStatus']?.toString(),
    );
  }

  // 勤怠データをスプレッドシートに送る形に変換
  Map<String, dynamic> toJson() {
    return {
      'rowId': rowId,
      'date': date,
      'userName': userName,
      'scheduledUse': scheduledUse,
      'attendance': attendanceStatus,
      'morningTask': morningTask,
      'afternoonTask': afternoonTask,
      'healthCondition': healthCondition,
      'sleepStatus': sleepStatus,
      'checkinComment': checkinComment,
      'fatigue': fatigue,
      'stress': stress,
      'checkoutComment': checkoutComment,
      'checkinTime': checkinTime,
      'checkoutTime': checkoutTime,
      'lunchBreak': lunchBreak,
      'shortBreak': shortBreak,
      'otherBreak': otherBreak,
      'actualWorkMinutes': actualWorkMinutes,
      'mealService': mealService,
      'absenceSupport': absenceSupport,
      'visitSupport': visitSupport,
      'transportService': transportService,
      'userStatus': userStatus,
    };
  }

  /// 支援記録が登録されているかどうか（Z列に入力があるか）
  bool get hasSupportRecord => userStatus != null && userStatus!.isNotEmpty;

  /// 一部のフィールドを変更した新しいインスタンスを作成
  Attendance copyWith({
    int? rowId,
    String? date,
    String? userName,
    String? scheduledUse,
    String? attendanceStatus,
    String? morningTask,
    String? afternoonTask,
    String? healthCondition,
    String? sleepStatus,
    String? checkinComment,
    String? fatigue,
    String? stress,
    String? checkoutComment,
    String? checkinTime,
    String? checkoutTime,
    String? lunchBreak,
    String? shortBreak,
    String? otherBreak,
    int? actualWorkMinutes,
    bool? mealService,
    bool? absenceSupport,
    bool? visitSupport,
    bool? transportService,
    String? userStatus,
    bool? hasSupportRecord, // 支援記録状態を直接設定するための特別パラメータ
  }) {
    return Attendance(
      rowId: rowId ?? this.rowId,
      date: date ?? this.date,
      userName: userName ?? this.userName,
      scheduledUse: scheduledUse ?? this.scheduledUse,
      attendanceStatus: attendanceStatus ?? this.attendanceStatus,
      morningTask: morningTask ?? this.morningTask,
      afternoonTask: afternoonTask ?? this.afternoonTask,
      healthCondition: healthCondition ?? this.healthCondition,
      sleepStatus: sleepStatus ?? this.sleepStatus,
      checkinComment: checkinComment ?? this.checkinComment,
      fatigue: fatigue ?? this.fatigue,
      stress: stress ?? this.stress,
      checkoutComment: checkoutComment ?? this.checkoutComment,
      checkinTime: checkinTime ?? this.checkinTime,
      checkoutTime: checkoutTime ?? this.checkoutTime,
      lunchBreak: lunchBreak ?? this.lunchBreak,
      shortBreak: shortBreak ?? this.shortBreak,
      otherBreak: otherBreak ?? this.otherBreak,
      actualWorkMinutes: actualWorkMinutes ?? this.actualWorkMinutes,
      mealService: mealService ?? this.mealService,
      absenceSupport: absenceSupport ?? this.absenceSupport,
      visitSupport: visitSupport ?? this.visitSupport,
      transportService: transportService ?? this.transportService,
      // hasSupportRecordがtrueならダミーの値を設定、falseならnull
      userStatus: hasSupportRecord != null
          ? (hasSupportRecord ? (this.userStatus ?? '登録済み') : null)
          : (userStatus ?? this.userStatus),
    );
  }
}
