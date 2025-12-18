/// アプリ全体で使う定数（変わらない値）
class AppConstants {
  // アプリ名
  static const String appName = 'B型施設 支援者サポートアプリ';

  // 年度の開始月（4月スタート）
  static const int fiscalYearStartMonth = 4;

  // エラーメッセージ
  static const String networkErrorMessage = 'ネットワークエラーが発生しました。通信環境をご確認ください。';
  static const String serverErrorMessage = 'サーバーエラーが発生しました。しばらくしてから再度お試しください。';
  static const String duplicateCheckinMessage = '本日はすでに出勤登録されています。';
  static const String duplicateCheckoutMessage = '本日はすでに退勤登録されています。';

  // 日付フォーマット
  static const String dateFormat = 'yyyy-MM-dd';
  static const String dateDisplayFormat = 'yyyy年MM月dd日';
  static const String timeFormat = 'HH:mm';
}
