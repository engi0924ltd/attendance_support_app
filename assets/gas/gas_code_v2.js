/**
 * B型施設 支援者サポートアプリ - Google Apps Script
 * 既存シート構造対応版（完全版）
 *
 * シート構成：
 * - マスタ設定: 利用者・職員・プルダウン選択肢
 * - 勤怠_2025: 日々の勤怠データ
 * - 支援記録_2025: 支援記録データ
 */

// === 設定 ===
const SHEET_NAMES = {
  MASTER: 'マスタ設定',
  ATTENDANCE: '勤怠_2025',
  SUPPORT: '支援記録_2025'
};

// マスタ設定シートの構造
const MASTER_CONFIG = {
  // 利用者セクション
  USER_HEADER_ROW: 6,
  USER_DATA_START_ROW: 8,      // 8行目から利用者データ開始
  DROPDOWN_START_ROW: 8,       // 8行目からプルダウン選択肢開始（基本）
  DROPDOWN_END_ROW: 29,        // 29行目まで選択肢（基本）

  // 退勤時プルダウン選択肢（疲労感・心理的負荷）
  CHECKOUT_DROPDOWN_START_ROW: 31,  // 31行目から退勤時選択肢開始
  CHECKOUT_DROPDOWN_END_ROW: 40,    // 40行目まで退勤時選択肢

  USER_COLS: {
    NAME: 1,        // A列
    FURIGANA: 2,    // B列
    STATUS: 3       // C列（契約状態）
  },

  // プルダウン列（D〜N列）8〜29行目
  DROPDOWN_COLS: {
    SCHEDULED: 4,          // D列: 出欠（予定）
    ATTENDANCE: 5,         // E列: 出欠
    MORNING_TASK: 6,       // F列: 担当業務AM
    AFTERNOON_TASK: 7,     // G列: 担当業務PM
    HEALTH: 8,             // H列: 本日の体調（8〜29行目）
    SLEEP: 9,              // I列: 睡眠状況（8〜29行目）
    CHECKIN_TIME: 10,      // J列: 勤務開始時刻
    CHECKOUT_TIME: 11,     // K列: 勤務終了時刻
    LUNCH_BREAK: 12,       // L列: 昼休憩
    SHORT_BREAK: 13,       // M列: 15分休憩
    OTHER_BREAK: 14        // N列: 他休憩時間
  },

  // 退勤時プルダウン列（H〜I列）31〜40行目
  CHECKOUT_DROPDOWN_COLS: {
    FATIGUE: 8,            // H列: 疲労感（31〜40行目）
    STRESS: 9              // I列: 心理的負荷（31〜40行目）
  },

  // 職員セクション
  STAFF_HEADER_ROW: 6,
  STAFF_DATA_START_ROW: 8,
  STAFF_DATA_END_ROW: 12,

  STAFF_COLS: {
    NAME: 16,       // P列: 職員名
    ROLE: 17,       // Q列: 権限
    EMAIL: 18,      // R列: メールアドレス
    PASSWORD: 19,   // S列: パスワード
    JOB_TYPE: 20    // T列: 職種
  }
};

// 勤怠_2025シートの列構成
const ATTENDANCE_COLS = {
  DATE: 4,              // D列: 日時
  USER_NAME: 5,         // E列: 利用者名
  SCHEDULED: 6,         // F列: 出欠（予定）
  ATTENDANCE: 7,        // G列: 出欠
  MORNING_TASK: 8,      // H列: 担当業務AM
  AFTERNOON_TASK: 9,    // I列: 担当業務PM
  WORKPLACE: 10,        // J列: 業務連絡
  HEALTH: 11,           // K列: 本日の体調
  SLEEP: 12,            // L列: 睡眠状況
  CHECKIN_COMMENT: 13,  // M列: 出勤時利用者コメント
  FATIGUE: 14,          // N列: 疲労感
  STRESS: 15,           // O列: 心理的負荷
  CHECKOUT_COMMENT: 16, // P列: 退勤時利用者コメント
  CHECKIN_TIME: 19,     // S列: 勤務開始時刻
  CHECKOUT_TIME: 20,    // T列: 勤務終了時刻
  LUNCH_BREAK: 21,      // U列: 昼休憩
  SHORT_BREAK: 23,      // W列: 15分休憩
  OTHER_BREAK: 25,      // Y列: 他休憩時間
  WORK_MINUTES: 26,     // Z列: 実労時間
  MEAL_SERVICE: 29,     // AC列: 食事提供
  ABSENCE_SUPPORT: 30,  // AD列: 欠席対応
  VISIT_SUPPORT: 31,    // AE列: 訪問支援
  TRANSPORT: 32         // AF列: 送迎
};

// === メイン処理 ===

/**
 * GETリクエスト処理
 */
function doGet(e) {
  try {
    const action = e.parameter.action || '';

    if (action === 'master/users') {
      return handleGetUsers();
    } else if (action === 'master/dropdowns') {
      return handleGetDropdowns();
    } else if (action === 'staff/list') {
      return handleGetStaffList();
    } else if (action.startsWith('attendance/daily/')) {
      const date = action.split('/')[2];
      return handleGetDailyAttendance(date);
    }

    return createErrorResponse('無効なアクション: ' + action);
  } catch (error) {
    return createErrorResponse('サーバーエラー: ' + error.message);
  }
}

/**
 * POSTリクエスト処理
 */
function doPost(e) {
  try {
    const data = JSON.parse(e.postData.contents);
    const action = data.action || '';

    if (action === 'auth/staff/login') {
      return handleStaffLogin(data);
    } else if (action === 'staff/create') {
      return handleCreateStaff(data);
    } else if (action === 'staff/update') {
      return handleUpdateStaff(data);
    } else if (action === 'staff/delete') {
      return handleDeleteStaff(data);
    } else if (action === 'attendance/checkin') {
      return handleCheckin(data);
    } else if (action === 'attendance/checkout') {
      return handleCheckout(data);
    }

    return createErrorResponse('無効なアクション: ' + action);
  } catch (error) {
    return createErrorResponse('サーバーエラー: ' + error.message);
  }
}

// === 利用者マスタ取得 ===

/**
 * 契約中の利用者一覧を取得
 */
function handleGetUsers() {
  const sheet = getSheet(SHEET_NAMES.MASTER);
  const users = [];

  // 利用者データ行を動的に読み取り（8行目から空白まで）
  let row = MASTER_CONFIG.USER_DATA_START_ROW;

  while (row <= 1000) {  // 最大1000行まで
    const name = sheet.getRange(row, MASTER_CONFIG.USER_COLS.NAME).getValue();

    // 空白行に達したら終了
    if (!name || name === '') {
      break;
    }

    const furigana = sheet.getRange(row, MASTER_CONFIG.USER_COLS.FURIGANA).getValue();
    const status = sheet.getRange(row, MASTER_CONFIG.USER_COLS.STATUS).getValue();

    // 契約中の利用者のみ返す
    if (status === '契約中') {
      users.push({
        name: name,
        furigana: furigana || '',
        status: status
      });
    }

    row++;
  }

  return createSuccessResponse({ users });
}

// === プルダウン選択肢取得 ===

/**
 * プルダウン選択肢を取得
 */
function handleGetDropdowns() {
  const sheet = getSheet(SHEET_NAMES.MASTER);

  // 時間リスト用の列番号を定義（P列=16, Q列=17）
  const TIME_LIST_COLS = {
    CHECKIN: 16,   // P列: 出勤時間リスト（8〜40行目）
    CHECKOUT: 17   // Q列: 退勤時間リスト（8〜40行目）
  };

  const options = {
    scheduledUse: getColumnOptions(sheet, MASTER_CONFIG.DROPDOWN_COLS.SCHEDULED),                                                                                // D列: 出欠（予定）
    attendanceStatus: getColumnOptions(sheet, MASTER_CONFIG.DROPDOWN_COLS.ATTENDANCE),                                                                           // E列: 出欠
    tasks: getColumnOptions(sheet, MASTER_CONFIG.DROPDOWN_COLS.MORNING_TASK),                                                                                    // F列: 担当業務（午前・午後共通）
    healthCondition: getColumnOptions(sheet, MASTER_CONFIG.DROPDOWN_COLS.HEALTH),                                                                                // H列: 本日の体調（8〜29行目）
    sleepStatus: getColumnOptions(sheet, MASTER_CONFIG.DROPDOWN_COLS.SLEEP),                                                                                     // I列: 睡眠状況（8〜29行目）
    fatigue: getColumnOptions(sheet, MASTER_CONFIG.CHECKOUT_DROPDOWN_COLS.FATIGUE, MASTER_CONFIG.CHECKOUT_DROPDOWN_START_ROW, MASTER_CONFIG.CHECKOUT_DROPDOWN_END_ROW),  // H列: 疲労感（31〜40行目）
    stress: getColumnOptions(sheet, MASTER_CONFIG.CHECKOUT_DROPDOWN_COLS.STRESS, MASTER_CONFIG.CHECKOUT_DROPDOWN_START_ROW, MASTER_CONFIG.CHECKOUT_DROPDOWN_END_ROW),    // I列: 心理的負荷（31〜40行目）
    checkinTimes: getColumnOptions(sheet, TIME_LIST_COLS.CHECKIN, 8, 40),                                                                                        // P列: 出勤時間リスト（8〜40行目）
    checkoutTimes: getColumnOptions(sheet, TIME_LIST_COLS.CHECKOUT, 8, 40),                                                                                      // Q列: 退勤時間リスト（8〜40行目）
    specialNotes: [],                                                                                                                                             // 特記事項（使用しない）
    breaks: [],                                                                                                                                                   // 休憩時間（使用しない）
    workLocations: [],                                                                                                                                            // 勤務地（使用しない）
    evaluations: []                                                                                                                                               // 評価項目（使用しない）
  };

  Logger.log('📊 [handleGetDropdowns] checkinTimes: ' + JSON.stringify(options.checkinTimes));
  Logger.log('📊 [handleGetDropdowns] checkoutTimes: ' + JSON.stringify(options.checkoutTimes));

  return createSuccessResponse(options);
}

/**
 * 指定列のプルダウン選択肢を取得
 */
function getColumnOptions(sheet, col, startRow, endRow) {
  const options = [];
  const start = startRow || MASTER_CONFIG.DROPDOWN_START_ROW;
  const end = endRow || MASTER_CONFIG.DROPDOWN_END_ROW;

  // 指定範囲から選択肢を読み取り
  for (let row = start; row <= end; row++) {
    const value = sheet.getRange(row, col).getValue();

    // 空白はスキップ（他の列と行が揃っていない場合があるため）
    if (value && value !== '') {
      // 時刻データ（Dateオブジェクト）の場合は"HH:mm"形式に変換
      if (value instanceof Date) {
        const hours = String(value.getHours()).padStart(2, '0');
        const minutes = String(value.getMinutes()).padStart(2, '0');
        options.push(`${hours}:${minutes}`);
      } else {
        // 通常のテキストデータ
        options.push(String(value));
      }
    }
  }

  return options;
}

// === 認証処理 ===

/**
 * 職員ログイン
 */
function handleStaffLogin(data) {
  const email = data.email;
  const password = data.password;

  Logger.log('=== Login Attempt ===');
  Logger.log('Email: ' + email);
  Logger.log('Password: ' + password);

  if (!email) {
    return createErrorResponse('メールアドレスが入力されていません');
  }

  if (!password) {
    return createErrorResponse('パスワードが入力されていません');
  }

  const sheet = getSheet(SHEET_NAMES.MASTER);

  Logger.log('=== Reading Staff Data ===');
  Logger.log('Column definitions: NAME=' + MASTER_CONFIG.STAFF_COLS.NAME +
             ', EMAIL=' + MASTER_CONFIG.STAFF_COLS.EMAIL +
             ', PASSWORD=' + MASTER_CONFIG.STAFF_COLS.PASSWORD);

  // 職員データ行を読み取り（8〜12行目）
  for (let row = MASTER_CONFIG.STAFF_DATA_START_ROW; row <= MASTER_CONFIG.STAFF_DATA_END_ROW; row++) {
    const staffName = sheet.getRange(row, MASTER_CONFIG.STAFF_COLS.NAME).getValue();
    const staffEmail = sheet.getRange(row, MASTER_CONFIG.STAFF_COLS.EMAIL).getValue();
    const staffPassword = sheet.getRange(row, MASTER_CONFIG.STAFF_COLS.PASSWORD).getValue();

    Logger.log('Row ' + row + ': Name=' + staffName + ', Email=' + staffEmail + ', Password=' + staffPassword);

    // メールアドレスとパスワードの両方が一致するかチェック
    if (staffEmail && staffEmail === email) {
      Logger.log('Email match found at row ' + row);
      if (staffPassword && staffPassword === password) {
        Logger.log('Password match - login successful');
        const token = generateToken(email);
        const staffRole = sheet.getRange(row, MASTER_CONFIG.STAFF_COLS.ROLE).getValue();

        return createSuccessResponse({
          staffName: staffName || '',
          email: staffEmail,
          role: staffRole || '支援員',  // スプレッドシートから取得（なければ固定値）
          token: token
        });
      } else {
        Logger.log('Password mismatch - expected: ' + staffPassword + ', got: ' + password);
        return createErrorResponse('パスワードが正しくありません');
      }
    }
  }

  Logger.log('Email not found in any row');
  return createErrorResponse('メールアドレスが登録されていません');
}

/**
 * トークン生成
 */
function generateToken(email) {
  const timestamp = new Date().getTime();
  return Utilities.base64Encode(email + ':' + timestamp);
}

// === 職員（支援者）管理 ===

/**
 * 職員一覧を取得
 */
function handleGetStaffList() {
  try {
    const sheet = getSheet(SHEET_NAMES.MASTER);
    const lastRow = sheet.getLastRow();
    const staffList = [];

    // 8行目から最終行まで走査
    for (let row = MASTER_CONFIG.STAFF_DATA_START_ROW; row <= lastRow; row++) {
      const name = sheet.getRange(row, MASTER_CONFIG.STAFF_COLS.NAME).getValue();
      const email = sheet.getRange(row, MASTER_CONFIG.STAFF_COLS.EMAIL).getValue();

      // 名前とメールアドレスが両方入力されている行のみ取得
      if (name && email) {
        const role = sheet.getRange(row, MASTER_CONFIG.STAFF_COLS.ROLE).getValue();
        const jobType = sheet.getRange(row, MASTER_CONFIG.STAFF_COLS.JOB_TYPE).getValue();

        staffList.push({
          name: name,
          email: email,
          role: role || '従業員',
          jobType: jobType || null,
          rowNumber: row
        });
      }
    }

    return createSuccessResponse({ staffList: staffList });

  } catch (error) {
    return createErrorResponse('職員一覧取得エラー: ' + error.message);
  }
}

/**
 * 職員を新規登録
 */
function handleCreateStaff(data) {
  try {
    // バリデーション
    if (!data.name) {
      return createErrorResponse('職員名を入力してください');
    }
    if (!data.email) {
      return createErrorResponse('メールアドレスを入力してください');
    }
    if (!data.password) {
      return createErrorResponse('パスワードを入力してください');
    }
    // パスワード強度チェック
    const passwordError = validatePassword(data.password);
    if (passwordError) {
      return createErrorResponse(passwordError);
    }
    if (!data.role || (data.role !== '管理者' && data.role !== '従業員')) {
      return createErrorResponse('権限は「管理者」または「従業員」を指定してください');
    }

    const sheet = getSheet(SHEET_NAMES.MASTER);
    const lastRow = sheet.getLastRow();

    // メールアドレスの重複チェック
    for (let row = MASTER_CONFIG.STAFF_DATA_START_ROW; row <= lastRow; row++) {
      const existingEmail = sheet.getRange(row, MASTER_CONFIG.STAFF_COLS.EMAIL).getValue();
      if (existingEmail && existingEmail.toLowerCase() === data.email.toLowerCase()) {
        return createErrorResponse('このメールアドレスは既に登録されています');
      }
    }

    // 空行を探す（P列が空の行）
    let newRow = -1;
    for (let row = MASTER_CONFIG.STAFF_DATA_START_ROW; row <= lastRow; row++) {
      const existingName = sheet.getRange(row, MASTER_CONFIG.STAFF_COLS.NAME).getValue();
      if (!existingName || existingName === '') {
        newRow = row;
        break;
      }
    }

    // 空行が見つからなければ最後に追加
    if (newRow === -1) {
      newRow = lastRow + 1;
    }

    // データを書き込む
    const cols = MASTER_CONFIG.STAFF_COLS;
    sheet.getRange(newRow, cols.NAME).setValue(data.name);
    sheet.getRange(newRow, cols.ROLE).setValue(data.role);
    sheet.getRange(newRow, cols.EMAIL).setValue(data.email);
    sheet.getRange(newRow, cols.PASSWORD).setValue(data.password);
    sheet.getRange(newRow, cols.JOB_TYPE).setValue(data.jobType || '');

    return createSuccessResponse({
      message: '職員を登録しました',
      staff: {
        name: data.name,
        email: data.email,
        role: data.role,
        jobType: data.jobType || null,
        rowNumber: newRow
      }
    });

  } catch (error) {
    return createErrorResponse('職員登録エラー: ' + error.message);
  }
}

/**
 * 職員情報を更新
 */
function handleUpdateStaff(data) {
  try {
    // バリデーション
    if (!data.rowNumber) {
      return createErrorResponse('行番号が指定されていません');
    }
    if (!data.name) {
      return createErrorResponse('職員名を入力してください');
    }
    if (!data.email) {
      return createErrorResponse('メールアドレスを入力してください');
    }
    if (!data.role || (data.role !== '管理者' && data.role !== '従業員')) {
      return createErrorResponse('権限は「管理者」または「従業員」を指定してください');
    }

    // パスワードが指定されている場合のみ強度チェック
    if (data.password) {
      const passwordError = validatePassword(data.password);
      if (passwordError) {
        return createErrorResponse(passwordError);
      }
    }

    const sheet = getSheet(SHEET_NAMES.MASTER);
    const lastRow = sheet.getLastRow();

    // メールアドレスの重複チェック（自分自身の行は除外）
    for (let row = MASTER_CONFIG.STAFF_DATA_START_ROW; row <= lastRow; row++) {
      if (row === data.rowNumber) continue; // 自分自身はスキップ

      const existingEmail = sheet.getRange(row, MASTER_CONFIG.STAFF_COLS.EMAIL).getValue();
      if (existingEmail && existingEmail.toLowerCase() === data.email.toLowerCase()) {
        return createErrorResponse('このメールアドレスは既に登録されています');
      }
    }

    // データを更新
    const cols = MASTER_CONFIG.STAFF_COLS;
    sheet.getRange(data.rowNumber, cols.NAME).setValue(data.name);
    sheet.getRange(data.rowNumber, cols.ROLE).setValue(data.role);
    sheet.getRange(data.rowNumber, cols.EMAIL).setValue(data.email);
    if (data.password) {
      sheet.getRange(data.rowNumber, cols.PASSWORD).setValue(data.password);
    }
    sheet.getRange(data.rowNumber, cols.JOB_TYPE).setValue(data.jobType || '');

    return createSuccessResponse({
      message: '職員情報を更新しました',
      staff: {
        name: data.name,
        email: data.email,
        role: data.role,
        jobType: data.jobType || null,
        rowNumber: data.rowNumber
      }
    });

  } catch (error) {
    return createErrorResponse('職員更新エラー: ' + error.message);
  }
}

/**
 * 職員を削除（行データをクリア）
 */
function handleDeleteStaff(data) {
  try {
    // バリデーション
    if (!data.rowNumber) {
      return createErrorResponse('行番号が指定されていません');
    }

    const sheet = getSheet(SHEET_NAMES.MASTER);

    // P-T列のデータをクリア
    const cols = MASTER_CONFIG.STAFF_COLS;
    sheet.getRange(data.rowNumber, cols.NAME).clearContent();
    sheet.getRange(data.rowNumber, cols.ROLE).clearContent();
    sheet.getRange(data.rowNumber, cols.EMAIL).clearContent();
    sheet.getRange(data.rowNumber, cols.PASSWORD).clearContent();
    sheet.getRange(data.rowNumber, cols.JOB_TYPE).clearContent();

    return createSuccessResponse({
      message: '職員を削除しました'
    });

  } catch (error) {
    return createErrorResponse('職員削除エラー: ' + error.message);
  }
}

/**
 * パスワードバリデーション
 * 大文字、小文字、数字を含む6文字以上
 */
function validatePassword(password) {
  if (!password || password.length < 6) {
    return 'パスワードは6文字以上で入力してください';
  }

  // 大文字チェック
  if (!/[A-Z]/.test(password)) {
    return 'パスワードには大文字を含めてください';
  }

  // 小文字チェック
  if (!/[a-z]/.test(password)) {
    return 'パスワードには小文字を含めてください';
  }

  // 数字チェック
  if (!/[0-9]/.test(password)) {
    return 'パスワードには数字を含めてください';
  }

  return null; // バリデーション成功
}

// === 勤怠データ処理 ===

/**
 * 出勤登録
 */
function handleCheckin(data) {
  try {
    const sheet = getSheet(SHEET_NAMES.ATTENDANCE);
    const date = data.date || formatDate(new Date());
    const userName = data.userName;

    if (!userName) {
      return createErrorResponse('利用者名が指定されていません');
    }

    // 同日の同利用者の記録が既にあるかチェック
    const existingRow = findAttendanceRow(sheet, date, userName);
    if (existingRow) {
      return createErrorResponse('既に出勤登録されています');
    }

    // 新しい行に追加
    const lastRow = sheet.getLastRow();
    const newRow = lastRow + 1;

    // 各列にデータを設定
    sheet.getRange(newRow, ATTENDANCE_COLS.DATE).setValue(date);
    sheet.getRange(newRow, ATTENDANCE_COLS.USER_NAME).setValue(userName);

    if (data.scheduledUse) sheet.getRange(newRow, ATTENDANCE_COLS.SCHEDULED).setValue(data.scheduledUse);
    if (data.attendance) sheet.getRange(newRow, ATTENDANCE_COLS.ATTENDANCE).setValue(data.attendance);
    if (data.morningTask) sheet.getRange(newRow, ATTENDANCE_COLS.MORNING_TASK).setValue(data.morningTask);
    if (data.afternoonTask) sheet.getRange(newRow, ATTENDANCE_COLS.AFTERNOON_TASK).setValue(data.afternoonTask);
    if (data.healthCondition) sheet.getRange(newRow, ATTENDANCE_COLS.HEALTH).setValue(data.healthCondition);
    if (data.sleepStatus) sheet.getRange(newRow, ATTENDANCE_COLS.SLEEP).setValue(data.sleepStatus);
    if (data.checkinComment) sheet.getRange(newRow, ATTENDANCE_COLS.CHECKIN_COMMENT).setValue(data.checkinComment);
    if (data.checkinTime) sheet.getRange(newRow, ATTENDANCE_COLS.CHECKIN_TIME).setValue(data.checkinTime);

    return createSuccessResponse({
      message: '出勤登録が完了しました',
      date: date,
      userName: userName
    });
  } catch (error) {
    return createErrorResponse('出勤登録エラー: ' + error.message);
  }
}

/**
 * 退勤登録
 */
function handleCheckout(data) {
  const sheet = getSheet(SHEET_NAMES.ATTENDANCE);
  const date = data.date;
  const userName = data.userName;
  const checkoutTime = data.checkoutTime;

  const rowIndex = findAttendanceRow(sheet, date, userName);

  if (!rowIndex) {
    return createErrorResponse('出勤記録が見つかりません');
  }

  // 退勤時刻を設定
  sheet.getRange(rowIndex, ATTENDANCE_COLS.CHECKOUT_TIME).setValue(checkoutTime);

  // 退勤時のデータを設定
  if (data.fatigue) sheet.getRange(rowIndex, ATTENDANCE_COLS.FATIGUE).setValue(data.fatigue);
  if (data.stress) sheet.getRange(rowIndex, ATTENDANCE_COLS.STRESS).setValue(data.stress);
  if (data.checkoutComment) sheet.getRange(rowIndex, ATTENDANCE_COLS.CHECKOUT_COMMENT).setValue(data.checkoutComment);

  // 実労時間を計算
  const checkinTime = sheet.getRange(rowIndex, ATTENDANCE_COLS.CHECKIN_TIME).getValue();
  const lunchBreak = sheet.getRange(rowIndex, ATTENDANCE_COLS.LUNCH_BREAK).getValue();
  const shortBreak = sheet.getRange(rowIndex, ATTENDANCE_COLS.SHORT_BREAK).getValue();
  const otherBreak = sheet.getRange(rowIndex, ATTENDANCE_COLS.OTHER_BREAK).getValue();

  const workMinutes = calculateWorkMinutes(checkinTime, checkoutTime, lunchBreak, shortBreak, otherBreak);
  sheet.getRange(rowIndex, ATTENDANCE_COLS.WORK_MINUTES).setValue(workMinutes);

  return createSuccessResponse({
    message: '退勤登録が完了しました',
    workMinutes: workMinutes
  });
}

/**
 * 指定日の勤怠一覧取得
 */
function handleGetDailyAttendance(date) {
  const sheet = getSheet(SHEET_NAMES.ATTENDANCE);
  const lastRow = sheet.getLastRow();
  const records = [];

  // 2行目（ヘッダーの次）から最終行まで
  for (let row = 2; row <= lastRow; row++) {
    const rowDate = formatDate(sheet.getRange(row, ATTENDANCE_COLS.DATE).getValue());

    if (rowDate === date) {
      records.push(parseAttendanceRow(sheet, row));
    }
  }

  return createSuccessResponse({ records });
}

/**
 * 勤怠データ行を探す
 */
function findAttendanceRow(sheet, date, userName) {
  const lastRow = sheet.getLastRow();

  for (let row = 2; row <= lastRow; row++) {
    const rowDate = formatDate(sheet.getRange(row, ATTENDANCE_COLS.DATE).getValue());
    const rowUserName = sheet.getRange(row, ATTENDANCE_COLS.USER_NAME).getValue();

    if (rowDate === date && rowUserName === userName) {
      return row;
    }
  }

  return null;
}

/**
 * 勤怠データ行をパース
 */
function parseAttendanceRow(sheet, row) {
  // ヘルパー関数：値を文字列に変換（空白の場合はnull）
  function toStringOrNull(value) {
    if (value === null || value === undefined || value === '') {
      return null;
    }
    return String(value);
  }

  // ヘルパー関数：値を整数に変換（エラー値や空白の場合はnull）
  function toIntOrNull(value) {
    if (value === null || value === undefined || value === '') {
      return null;
    }
    // エラー値（#NUM!、#VALUE!など）をチェック
    const valueStr = String(value);
    if (valueStr.startsWith('#')) {
      return null;
    }
    // 数値に変換
    const num = Number(value);
    if (isNaN(num)) {
      return null;
    }
    return Math.round(num);
  }

  return {
    rowId: row,
    date: formatDate(sheet.getRange(row, ATTENDANCE_COLS.DATE).getValue()),
    userName: toStringOrNull(sheet.getRange(row, ATTENDANCE_COLS.USER_NAME).getValue()),
    scheduledUse: toStringOrNull(sheet.getRange(row, ATTENDANCE_COLS.SCHEDULED).getValue()),
    attendance: toStringOrNull(sheet.getRange(row, ATTENDANCE_COLS.ATTENDANCE).getValue()),
    morningTask: toStringOrNull(sheet.getRange(row, ATTENDANCE_COLS.MORNING_TASK).getValue()),
    afternoonTask: toStringOrNull(sheet.getRange(row, ATTENDANCE_COLS.AFTERNOON_TASK).getValue()),
    healthCondition: toStringOrNull(sheet.getRange(row, ATTENDANCE_COLS.HEALTH).getValue()),
    sleepStatus: toStringOrNull(sheet.getRange(row, ATTENDANCE_COLS.SLEEP).getValue()),
    checkinComment: toStringOrNull(sheet.getRange(row, ATTENDANCE_COLS.CHECKIN_COMMENT).getValue()),
    fatigue: toStringOrNull(sheet.getRange(row, ATTENDANCE_COLS.FATIGUE).getValue()),
    stress: toStringOrNull(sheet.getRange(row, ATTENDANCE_COLS.STRESS).getValue()),
    checkoutComment: toStringOrNull(sheet.getRange(row, ATTENDANCE_COLS.CHECKOUT_COMMENT).getValue()),
    checkinTime: toStringOrNull(sheet.getRange(row, ATTENDANCE_COLS.CHECKIN_TIME).getValue()),
    checkoutTime: toStringOrNull(sheet.getRange(row, ATTENDANCE_COLS.CHECKOUT_TIME).getValue()),
    lunchBreak: toStringOrNull(sheet.getRange(row, ATTENDANCE_COLS.LUNCH_BREAK).getValue()),
    shortBreak: toStringOrNull(sheet.getRange(row, ATTENDANCE_COLS.SHORT_BREAK).getValue()),
    otherBreak: toStringOrNull(sheet.getRange(row, ATTENDANCE_COLS.OTHER_BREAK).getValue()),
    actualWorkMinutes: toIntOrNull(sheet.getRange(row, ATTENDANCE_COLS.WORK_MINUTES).getValue()),
    mealService: sheet.getRange(row, ATTENDANCE_COLS.MEAL_SERVICE).getValue() || false,
    absenceSupport: sheet.getRange(row, ATTENDANCE_COLS.ABSENCE_SUPPORT).getValue() || false,
    visitSupport: sheet.getRange(row, ATTENDANCE_COLS.VISIT_SUPPORT).getValue() || false,
    transportService: sheet.getRange(row, ATTENDANCE_COLS.TRANSPORT).getValue() || false
  };
}

// === ヘルパー関数 ===

/**
 * シート取得
 */
function getSheet(sheetName) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName(sheetName);

  if (!sheet) {
    throw new Error('シート "' + sheetName + '" が見つかりません');
  }

  return sheet;
}

/**
 * 日付フォーマット
 */
function formatDate(dateValue) {
  if (!dateValue) return '';
  if (typeof dateValue === 'string') return dateValue;

  const date = new Date(dateValue);
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');

  return `${year}-${month}-${day}`;
}

/**
 * 実労時間計算（分単位）
 */
function calculateWorkMinutes(checkinTime, checkoutTime, lunchBreak, shortBreak, otherBreak) {
  if (!checkinTime || !checkoutTime) return 0;

  const checkin = parseTime(checkinTime);
  const checkout = parseTime(checkoutTime);

  let totalMinutes = (checkout - checkin) / 60000;

  // 休憩時間を引く
  totalMinutes -= parseBreakTime(lunchBreak);
  totalMinutes -= parseBreakTime(shortBreak);
  totalMinutes -= parseBreakTime(otherBreak);

  return Math.max(0, Math.round(totalMinutes));
}

/**
 * 時刻文字列をDateオブジェクトに変換
 */
function parseTime(timeStr) {
  if (!timeStr) return new Date();

  const timeString = String(timeStr);
  const today = new Date();

  if (timeString.includes(':')) {
    const [hours, minutes] = timeString.split(':').map(Number);
    today.setHours(hours, minutes, 0, 0);
  }

  return today;
}

/**
 * 休憩時間を分に変換
 */
function parseBreakTime(breakValue) {
  if (!breakValue) return 0;

  const breakString = String(breakValue);

  // "1:00" 形式の場合
  if (breakString.includes(':')) {
    const [hours, minutes] = breakString.split(':').map(Number);
    return (hours * 60) + minutes;
  }

  // 数値の場合
  return parseInt(breakString) || 0;
}

/**
 * 成功レスポンス作成
 */
function createSuccessResponse(data) {
  const response = {
    success: true,
    ...data
  };

  return ContentService
    .createTextOutput(JSON.stringify(response))
    .setMimeType(ContentService.MimeType.JSON);
}

/**
 * エラーレスポンス作成
 */
function createErrorResponse(message) {
  const response = {
    success: false,
    message: message
  };

  return ContentService
    .createTextOutput(JSON.stringify(response))
    .setMimeType(ContentService.MimeType.JSON);
}
