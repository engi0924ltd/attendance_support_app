/// スプレッドシートと通信するための設定
class ApiConfig {
  // 施設用GAS URL
  // 支援者ログイン、利用者登録、勤怠管理などで使用
  // 注意：空文字列のため、必ず施設コード入力またはログインでURLを設定する必要があります
  static const String baseUrl = '';

  // マスター管理GAS URL（全施設管理用）
  static const String masterUrl = 'https://script.google.com/macros/s/AKfycbxvgU61HKF21_8BdHs5re4nTUDTfyckzAGIe5-2nsBeUqEZCQag-i9sSxxUzogp2ngHuQ/exec';

  // タイムアウト時間（通信が遅い時に待つ時間）
  // 施設登録はスプレッドシートコピーに時間がかかるため60秒に設定
  static const Duration timeout = Duration(seconds: 60);
}
