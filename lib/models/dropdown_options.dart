/// プルダウンの選択肢
class DropdownOptions {
  final List<String> scheduledUse;        // 利用予定
  final List<String> attendanceStatus;    // 出欠（内容）
  final List<String> tasks;               // 担当業務
  final List<String> healthCondition;     // 本日の体調
  final List<String> sleepStatus;         // 睡眠状況
  final List<String> fatigue;             // 疲労感
  final List<String> stress;              // 心理的負荷
  final List<String> lunchBreak;          // 昼休憩
  final List<String> shortBreak;          // 15分休憩
  final List<String> otherBreak;          // その他休憩
  final List<String> specialNotes;        // 特記事項
  final List<String> breaks;              // 休憩時間
  final List<String> workLocations;       // 勤務地
  final List<String> qualifications;      // 保有福祉資格
  final List<String> placements;          // 職員配置
  final List<String> jobTypes;            // 職種
  final List<String> employmentTypes;     // 雇用形態
  final List<String> scheduledWeekly;     // 曜日別出欠予定
  final List<String> recorders;           // 記録者
  // 評価項目プルダウン
  final List<String> workEvaluations;     // 勤怠評価
  final List<String> employmentEvaluations; // 就労評価（品質・生産性）
  final List<String> workMotivations;     // 就労意欲
  final List<String> communications;      // 通信連絡対応度
  final List<String> evaluations;         // 評価
  // 名簿用プルダウン
  final List<String> rosterStatus;        // ステータス
  final List<String> lifeProtection;      // 生活保護
  final List<String> disabilityPension;   // 障がい者手帳年金
  final List<String> disabilityGrade;     // 障害等級
  final List<String> disabilityType;      // 障害種別
  final List<String> supportLevel;        // 障害支援区分
  final List<String> contractType;        // 契約形態
  final List<String> employmentSupport;   // 定着支援有無
  // 時間丸め用の時間リスト
  final List<String> checkinTimeList;     // 勤務開始時刻（15分刻み）
  final List<String> checkoutTimeList;    // 勤務終了時刻（15分刻み）

  DropdownOptions({
    required this.scheduledUse,
    required this.attendanceStatus,
    required this.tasks,
    required this.healthCondition,
    required this.sleepStatus,
    required this.fatigue,
    required this.stress,
    required this.lunchBreak,
    required this.shortBreak,
    required this.otherBreak,
    required this.specialNotes,
    required this.breaks,
    required this.workLocations,
    required this.qualifications,
    required this.placements,
    required this.jobTypes,
    required this.employmentTypes,
    required this.scheduledWeekly,
    required this.recorders,
    required this.workEvaluations,
    required this.employmentEvaluations,
    required this.workMotivations,
    required this.communications,
    required this.evaluations,
    required this.rosterStatus,
    required this.lifeProtection,
    required this.disabilityPension,
    required this.disabilityGrade,
    required this.disabilityType,
    required this.supportLevel,
    required this.contractType,
    required this.employmentSupport,
    required this.checkinTimeList,
    required this.checkoutTimeList,
  });

  // スプレッドシートから受け取ったデータをプルダウン選択肢に変換
  factory DropdownOptions.fromJson(Map<String, dynamic> json) {
    return DropdownOptions(
      scheduledUse: List<String>.from(json['scheduledUse'] ?? []),
      attendanceStatus: List<String>.from(json['attendanceStatus'] ?? []),
      tasks: List<String>.from(json['tasks'] ?? []),
      healthCondition: List<String>.from(json['healthCondition'] ?? []),
      sleepStatus: List<String>.from(json['sleepStatus'] ?? []),
      fatigue: List<String>.from(json['fatigue'] ?? []),
      stress: List<String>.from(json['stress'] ?? []),
      lunchBreak: List<String>.from(json['lunchBreak'] ?? []),
      shortBreak: List<String>.from(json['shortBreak'] ?? []),
      otherBreak: List<String>.from(json['otherBreak'] ?? []),
      specialNotes: List<String>.from(json['specialNotes'] ?? []),
      breaks: List<String>.from(json['breaks'] ?? []),
      workLocations: List<String>.from(json['workLocations'] ?? []),
      qualifications: List<String>.from(json['qualifications'] ?? []),
      placements: List<String>.from(json['placements'] ?? []),
      jobTypes: List<String>.from(json['jobTypes'] ?? []),
      employmentTypes: List<String>.from(json['employmentTypes'] ?? []),
      scheduledWeekly: List<String>.from(json['scheduledWeekly'] ?? []),
      recorders: List<String>.from(json['recorders'] ?? []),
      workEvaluations: List<String>.from(json['workEvaluations'] ?? []),
      employmentEvaluations: List<String>.from(json['employmentEvaluations'] ?? []),
      workMotivations: List<String>.from(json['workMotivations'] ?? []),
      communications: List<String>.from(json['communications'] ?? []),
      evaluations: List<String>.from(json['evaluations'] ?? []),
      rosterStatus: List<String>.from(json['rosterStatus'] ?? []),
      lifeProtection: List<String>.from(json['lifeProtection'] ?? []),
      disabilityPension: List<String>.from(json['disabilityPension'] ?? []),
      disabilityGrade: List<String>.from(json['disabilityGrade'] ?? []),
      disabilityType: List<String>.from(json['disabilityType'] ?? []),
      supportLevel: List<String>.from(json['supportLevel'] ?? []),
      contractType: List<String>.from(json['contractType'] ?? []),
      employmentSupport: List<String>.from(json['employmentSupport'] ?? []),
      checkinTimeList: List<String>.from(json['checkinTimeList'] ?? []),
      checkoutTimeList: List<String>.from(json['checkoutTimeList'] ?? []),
    );
  }
}
