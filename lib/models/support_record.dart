/// 支援記録データ
class SupportRecord {
  final int? rowId; // スプレッドシートの行番号

  // A-Y列: 勤怠_2025から自動反映される項目
  final String date; // A列: 日時
  final String userName; // B列: 利用者名
  final String? scheduled; // C列: 出欠（予定）
  final String? attendance; // D列: 出欠
  final String? morningTask; // E列: 担当業務AM
  final String? afternoonTask; // F列: 担当業務PM
  final String? workplace; // G列: 業務連絡
  final String? health; // H列: 本日の体調
  final String? sleep; // I列: 睡眠状況
  final String? checkinComment; // J列: 出勤時利用者コメント
  final String? fatigue; // K列: 疲労感
  final String? stress; // L列: 心理的負荷
  final String? checkoutComment; // M列: 退勤時利用者コメント
  final String? checkinTime; // P列: 勤務開始時刻
  final String? checkoutTime; // Q列: 勤務終了時刻
  final String? lunchBreak; // R列: 昼休憩
  final String? shortBreak; // S列: 15分休憩
  final String? otherBreak; // T列: 他休憩時間
  final dynamic workMinutes; // U列: 実労時間
  final String? mealService; // V列: 食事提供
  final String? absenceSupport; // W列: 欠席対応
  final String? visitSupport; // X列: 訪問支援
  final String? transport; // Y列: 送迎

  // Z-AL列: アプリから手動入力する支援記録項目
  final String? userStatus; // Z列: 本人の状況/欠勤時対応/施設外評価/在宅評価
  final String? workLocation; // AA列: 勤務地
  final String? recorder; // AB列: 記録者
  final String? homeSupportEval; // AD列: 在宅支援評価対象
  final String? externalEval; // AE列: 施設外評価対象
  final String? workGoal; // AF列: 作業目標
  final String? workEval; // AG列: 勤務評価
  final String? employmentEval; // AH列: 就労評価（品質・生産性）
  final String? workMotivation; // AI列: 就労意欲
  final String? communication; // AJ列: 通信連絡対応
  final String? evaluation; // AK列: 評価
  final String? userFeedback; // AL列: 利用者の感想

  SupportRecord({
    this.rowId,
    required this.date,
    required this.userName,
    this.scheduled,
    this.attendance,
    this.morningTask,
    this.afternoonTask,
    this.workplace,
    this.health,
    this.sleep,
    this.checkinComment,
    this.fatigue,
    this.stress,
    this.checkoutComment,
    this.checkinTime,
    this.checkoutTime,
    this.lunchBreak,
    this.shortBreak,
    this.otherBreak,
    this.workMinutes,
    this.mealService,
    this.absenceSupport,
    this.visitSupport,
    this.transport,
    this.userStatus,
    this.workLocation,
    this.recorder,
    this.homeSupportEval,
    this.externalEval,
    this.workGoal,
    this.workEval,
    this.employmentEval,
    this.workMotivation,
    this.communication,
    this.evaluation,
    this.userFeedback,
  });

  /// GASから受け取ったJSONデータを支援記録データに変換
  factory SupportRecord.fromJson(Map<String, dynamic> json) {
    return SupportRecord(
      rowId: json['rowId'],
      date: json['date']?.toString() ?? '',
      userName: json['userName']?.toString() ?? '',
      scheduled: json['scheduled']?.toString(),
      attendance: json['attendance']?.toString(),
      morningTask: json['morningTask']?.toString(),
      afternoonTask: json['afternoonTask']?.toString(),
      workplace: json['workplace']?.toString(),
      health: json['health']?.toString(),
      sleep: json['sleep']?.toString(),
      checkinComment: json['checkinComment']?.toString(),
      fatigue: json['fatigue']?.toString(),
      stress: json['stress']?.toString(),
      checkoutComment: json['checkoutComment']?.toString(),
      checkinTime: json['checkinTime']?.toString(),
      checkoutTime: json['checkoutTime']?.toString(),
      lunchBreak: json['lunchBreak']?.toString(),
      shortBreak: json['shortBreak']?.toString(),
      otherBreak: json['otherBreak']?.toString(),
      workMinutes: json['workMinutes'],
      mealService: json['mealService']?.toString(),
      absenceSupport: json['absenceSupport']?.toString(),
      visitSupport: json['visitSupport']?.toString(),
      transport: json['transport']?.toString(),
      userStatus: json['userStatus']?.toString(),
      workLocation: json['workLocation']?.toString(),
      recorder: json['recorder']?.toString(),
      homeSupportEval: json['homeSupportEval']?.toString(),
      externalEval: json['externalEval']?.toString(),
      workGoal: json['workGoal']?.toString(),
      workEval: json['workEval']?.toString(),
      employmentEval: json['employmentEval']?.toString(),
      workMotivation: json['workMotivation']?.toString(),
      communication: json['communication']?.toString(),
      evaluation: json['evaluation']?.toString(),
      userFeedback: json['userFeedback']?.toString(),
    );
  }

  /// 支援記録データをGASに送信する形式に変換
  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'userName': userName,
      'userStatus': userStatus,
      'workLocation': workLocation,
      'recorder': recorder,
      'homeSupportEval': homeSupportEval,
      'externalEval': externalEval,
      'workGoal': workGoal,
      'workEval': workEval,
      'employmentEval': employmentEval,
      'workMotivation': workMotivation,
      'communication': communication,
      'evaluation': evaluation,
      'userFeedback': userFeedback,
    };
  }

  /// 支援記録のコピーを作成（一部フィールドを更新）
  SupportRecord copyWith({
    String? userStatus,
    String? workLocation,
    String? recorder,
    String? homeSupportEval,
    String? externalEval,
    String? workGoal,
    String? workEval,
    String? employmentEval,
    String? workMotivation,
    String? communication,
    String? evaluation,
    String? userFeedback,
  }) {
    return SupportRecord(
      rowId: rowId,
      date: date,
      userName: userName,
      scheduled: scheduled,
      attendance: attendance,
      morningTask: morningTask,
      afternoonTask: afternoonTask,
      workplace: workplace,
      health: health,
      sleep: sleep,
      checkinComment: checkinComment,
      fatigue: fatigue,
      stress: stress,
      checkoutComment: checkoutComment,
      checkinTime: checkinTime,
      checkoutTime: checkoutTime,
      lunchBreak: lunchBreak,
      shortBreak: shortBreak,
      otherBreak: otherBreak,
      workMinutes: workMinutes,
      mealService: mealService,
      absenceSupport: absenceSupport,
      visitSupport: visitSupport,
      transport: transport,
      userStatus: userStatus ?? this.userStatus,
      workLocation: workLocation ?? this.workLocation,
      recorder: recorder ?? this.recorder,
      homeSupportEval: homeSupportEval ?? this.homeSupportEval,
      externalEval: externalEval ?? this.externalEval,
      workGoal: workGoal ?? this.workGoal,
      workEval: workEval ?? this.workEval,
      employmentEval: employmentEval ?? this.employmentEval,
      workMotivation: workMotivation ?? this.workMotivation,
      communication: communication ?? this.communication,
      evaluation: evaluation ?? this.evaluation,
      userFeedback: userFeedback ?? this.userFeedback,
    );
  }
}
