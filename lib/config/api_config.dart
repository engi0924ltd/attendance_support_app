/// スプレッドシートと通信するための設定
class ApiConfig {
  // 施設用GAS URL（111111_マスタ設定_2025）
  // 支援者ログイン、利用者登録、勤怠管理などで使用
  static const String baseUrl = 'https://script.google.com/macros/s/AKfycbwIiqM30n-zmgKvQkFAitEN0VUcH4UKgv5iQVIpM_oupgPFLqh4AcpyLZuc7-jd3h7Rqw/exec';

  // マスター管理GAS URL（全施設管理用）
  static const String masterUrl = 'https://script.google.com/macros/s/AKfycbxvgU61HKF21_8BdHs5re4nTUDTfyckzAGIe5-2nsBeUqEZCQag-i9sSxxUzogp2ngHuQ/exec';

  // タイムアウト時間（通信が遅い時に待つ時間）
  // 施設登録はスプレッドシートコピーに時間がかかるため60秒に設定
  static const Duration timeout = Duration(seconds: 60);
}
