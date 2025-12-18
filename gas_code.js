/**
 * B型施設 支援者サポートアプリ - Google Apps Script
 *
 * このスクリプトは、Flutterアプリとスプレッドシートを連携させます
 *
 * 必要なシート構成：
 * - マスタ設定
 * - 勤怠_2025（年度は適宜変更）
 * - 支援記録_2025（年度は適宜変更）
 */

// === 設定 ===
const SHEET_NAMES = {
  MASTER: 'マスタ設定',
  ATTENDANCE: '勤怠_2025',  // 年度に応じて変更してください
  SUPPORT_RECORD: '支援記録_2025'
};

// マスタ設定シート内の開始行
const MASTER_ROWS = {
  USER: 2,           // 利用者マスタ開始行
  STAFF: 2,          // 職員マスタ開始行（利用者の後）
  DROPDOWN: 2,       // プルダウン選択肢マスタ開始行
  TASK: 2            // 担当業務マスタ開始行
};

// === メイン処理 ===

/**
 * GETリクエスト処理（データ取得）
 */
function doGet(e) {
  try {
    const action = e.parameter.action || '';

    // actionに応じて処理を振り分け
    if (action.startsWith('master/users')) {
      return handleGetUsers();
    } else if (action.startsWith('master/dropdowns')) {
      return handleGetDropdowns();
    } else if (action.startsWith('attendance/daily/')) {
      const date = action.split('/')[2];
      return handleGetDailyAttendance(date);
    } else if (action.startsWith('attendance/user/')) {
      const parts = action.split('/');
      const userName = parts[2];
      const date = parts[3];
      return handleGetUserAttendance(userName, date);
    }

    return createErrorResponse('無効なアクション: ' + action);
  } catch (error) {
    return createErrorResponse('サーバーエラー: ' + error.message);
  }
}

/**
 * POSTリクエスト処理（データ送信）
 */
function doPost(e) {
  try {
    const data = JSON.parse(e.postData.contents);
    const action = data.action || '';

    // actionに応じて処理を振り分け
    if (action === 'auth/staff/login') {
      return handleStaffLogin(data);
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

/**
 * PUTリクエスト処理（データ更新）
 */
function doPut(e) {
  try {
    const data = JSON.parse(e.postData.contents);
    const action = data.action || '';

    if (action.startsWith('attendance/update/')) {
      return handleUpdateAttendance(data);
    }

    return createErrorResponse('無効なアクション: ' + action);
  } catch (error) {
    return createErrorResponse('サーバーエラー: ' + error.message);
  }
}

// === マスタデータ取得 ===

/**
 * 利用者マスタ取得（在籍中のみ）
 */
function handleGetUsers() {
  const sheet = getSheet(SHEET_NAMES.MASTER);
  const data = sheet.getDataRange().getValues();

  const users = [];

  // 利用者マスタ部分を読み取り（A列にIDがある行）
  for (let i = MASTER_ROWS.USER - 1; i < data.length; i++) {
    const row = data[i];

    // 空行またはスタッフマスタの開始（区切り）に達したら終了
    if (!row[0] || row[0] === '職員マスタ') break;

    const status = row[3] || '在籍';

    // 在籍中の利用者のみ返す
    if (status === '在籍') {
      users.push({
        id: row[0],
        name: row[1],
        furigana: row[2],
        status: status
      });
    }
  }

  return createSuccessResponse({ users });
}

/**
 * プルダウン選択肢マスタ取得
 */
function handleGetDropdowns() {
  const sheet = getSheet(SHEET_NAMES.MASTER);
  const data = sheet.getDataRange().getValues();

  const options = {
    scheduledUse: [],
    attendanceStatus: [],
    tasks: [],
    healthCondition: [],
    sleepStatus: [],
    specialNotes: [],
    breaks: [],
    workLocations: [],
    evaluations: []
  };

  // プルダウン選択肢マスタ部分を読み取り
  let foundDropdownSection = false;

  for (let i = 0; i < data.length; i++) {
    const row = data[i];

    // プルダウン選択肢マスタセクションを探す
    if (row[0] === 'プルダウン選択肢マスタ') {
      foundDropdownSection = true;
      continue;
    }

    if (!foundDropdownSection) continue;

    // 次のセクション（担当業務マスタ等）に達したら終了
    if (row[0] && row[0].includes('マスタ')) break;

    const category = row[0];
    const option = row[1];
    const isActive = row[3] === '有効';

    if (!category || !option || !isActive) continue;

    // カテゴリに応じて振り分け
    switch (category) {
      case '利用予定':
        options.scheduledUse.push(option);
        break;
      case '出欠（内容）':
        options.attendanceStatus.push(option);
        break;
      case '本日の体調':
        options.healthCondition.push(option);
        break;
      case '睡眠状況':
        options.sleepStatus.push(option);
        break;
      case '特記事項':
        options.specialNotes.push(option);
        break;
      case '休憩':
        options.breaks.push(option);
        break;
      case '勤務地':
        options.workLocations.push(option);
        break;
      case '評価':
        options.evaluations.push(option);
        break;
    }
  }

  // 担当業務マスタを読み取り
  let foundTaskSection = false;

  for (let i = 0; i < data.length; i++) {
    const row = data[i];

    if (row[0] === '担当業務マスタ') {
      foundTaskSection = true;
      continue;
    }

    if (!foundTaskSection) continue;
    if (!row[0] || row[0].includes('マスタ')) break;

    const taskName = row[1];
    const isActive = row[4] === '有効';

    if (taskName && isActive) {
      options.tasks.push(taskName);
    }
  }

  return createSuccessResponse(options);
}

// === 認証処理 ===

/**
 * 職員ログイン
 */
function handleStaffLogin(data) {
  const email = data.email;

  if (!email) {
    return createErrorResponse('メールアドレスが入力されていません');
  }

  const sheet = getSheet(SHEET_NAMES.MASTER);
  const values = sheet.getDataRange().getValues();

  // 職員マスタセクションを探す
  let foundStaffSection = false;

  for (let i = 0; i < values.length; i++) {
    const row = values[i];

    if (row[0] === '職員マスタ') {
      foundStaffSection = true;
      continue;
    }

    if (!foundStaffSection) continue;

    // 次のセクションに達したら終了
    if (row[0] && row[0].includes('マスタ') && row[0] !== '職員マスタ') break;

    const staffEmail = row[2];
    const alias1 = row[3];
    const alias2 = row[4];
    const status = row[5];

    // メールアドレスまたはエイリアスが一致し、在職中の場合
    if (status === '在職' && (email === staffEmail || email === alias1 || email === alias2)) {
      const token = generateToken(email);

      return createSuccessResponse({
        staffName: row[1],
        email: staffEmail,
        role: row[6] || '支援員',
        token: token
      });
    }
  }

  return createErrorResponse('メールアドレスが登録されていません');
}

/**
 * トークン生成（簡易版）
 */
function generateToken(email) {
  const timestamp = new Date().getTime();
  return Utilities.base64Encode(email + ':' + timestamp);
}

// === 勤怠データ処理 ===

/**
 * 出勤登録
 */
function handleCheckin(data) {
  try {
    const sheet = getSheet(SHEET_NAMES.ATTENDANCE);
    const date = data.date || new Date().toISOString().split('T')[0];
    const userName = data.userName;

    if (!userName) {
      return createErrorResponse('利用者名が指定されていません');
    }

    // 同じ日付・利用者の記録が既にあるかチェック
    const existingRow = findAttendanceRow(sheet, date, userName);

    if (existingRow) {
      return createErrorResponse('既に出勤登録されています');
    }

    // 新しい行を追加
    const newRow = createAttendanceRow(data);
    sheet.appendRow(newRow);

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

  // T列（退社時間）を更新
  sheet.getRange(rowIndex, 20).setValue(checkoutTime);

  // 実労時間を計算して更新
  const checkinTime = sheet.getRange(rowIndex, 19).getValue();
  const workMinutes = calculateWorkMinutes(checkinTime, checkoutTime, data);
  sheet.getRange(rowIndex, 26).setValue(workMinutes);

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
  const data = sheet.getDataRange().getValues();

  const records = [];

  for (let i = 1; i < data.length; i++) {  // ヘッダー行をスキップ
    const row = data[i];
    const rowDate = formatDate(row[3]);  // D列: 日時

    if (rowDate === date) {
      records.push(parseAttendanceRow(row, i + 1));
    }
  }

  return createSuccessResponse({ records });
}

/**
 * 特定利用者の勤怠データ取得
 */
function handleGetUserAttendance(userName, date) {
  const sheet = getSheet(SHEET_NAMES.ATTENDANCE);
  const rowIndex = findAttendanceRow(sheet, date, userName);

  if (!rowIndex) {
    return createSuccessResponse({ record: null });
  }

  const row = sheet.getRange(rowIndex, 1, 1, sheet.getLastColumn()).getValues()[0];
  const record = parseAttendanceRow(row, rowIndex);

  return createSuccessResponse({ record });
}

/**
 * 勤怠データ更新
 */
function handleUpdateAttendance(data) {
  const sheet = getSheet(SHEET_NAMES.ATTENDANCE);
  const rowId = data.rowId;

  if (!rowId || rowId < 2) {
    return createErrorResponse('無効な行番号です');
  }

  // 各列を更新
  const updates = [
    { col: 4, value: data.date },                    // D: 日時
    { col: 5, value: data.userName },                // E: 利用者名
    { col: 6, value: data.scheduledUse },            // F: 利用予定
    { col: 7, value: data.attendance },              // G: 出欠
    { col: 8, value: data.morningTask },             // H: 担当業務AM
    { col: 9, value: data.afternoonTask },           // I: 担当業務PM
    { col: 10, value: data.userComment },            // J: 利用者コメント
    { col: 11, value: data.healthCondition },        // K: 本日の体調
    { col: 12, value: data.sleepStatus },            // L: 睡眠状況
    { col: 13, value: data.specialNotes },           // M: 特記事項
    { col: 19, value: data.checkinTime },            // S: 出勤時間
    { col: 20, value: data.checkoutTime },           // T: 退社時間
    { col: 21, value: data.lunchBreak },             // U: 昼休憩
    { col: 23, value: data.shortBreak },             // W: 15分休
    { col: 25, value: data.otherBreak },             // Y: 他休憩
    { col: 26, value: data.actualWorkMinutes },      // Z: 実労時間
    { col: 29, value: data.mealService ? '○' : '' },        // AC: 食事提供加算
    { col: 30, value: data.absenceSupport ? '○' : '' },     // AD: 欠席対応加算
    { col: 31, value: data.visitSupport ? '○' : '' },       // AE: 訪問支援加算
    { col: 32, value: data.transportService ? '○' : '' }    // AF: 送迎加算
  ];

  updates.forEach(update => {
    if (update.value !== undefined && update.value !== null) {
      sheet.getRange(rowId, update.col).setValue(update.value);
    }
  });

  return createSuccessResponse({ message: '更新が完了しました' });
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
 * 勤怠データの行を探す
 */
function findAttendanceRow(sheet, date, userName) {
  const data = sheet.getDataRange().getValues();

  for (let i = 1; i < data.length; i++) {
    const rowDate = formatDate(data[i][3]);  // D列
    const rowUserName = data[i][4];          // E列

    if (rowDate === date && rowUserName === userName) {
      return i + 1;  // 行番号は1始まり
    }
  }

  return null;
}

/**
 * 勤怠データ行を作成
 */
function createAttendanceRow(data) {
  const row = new Array(32);  // AF列まで

  row[3] = data.date;                       // D: 日時
  row[4] = data.userName;                   // E: 利用者名
  row[5] = data.scheduledUse;               // F: 利用予定
  row[6] = data.attendance;                 // G: 出欠
  row[7] = data.morningTask;                // H: 担当業務AM
  row[8] = data.afternoonTask;              // I: 担当業務PM
  row[9] = data.userComment;                // J: 利用者コメント
  row[10] = data.healthCondition;           // K: 本日の体調
  row[11] = data.sleepStatus;               // L: 睡眠状況
  row[12] = data.specialNotes;              // M: 特記事項
  row[18] = data.checkinTime;               // S: 出勤時間
  row[19] = data.checkoutTime;              // T: 退社時間
  row[20] = data.lunchBreak;                // U: 昼休憩
  row[22] = data.shortBreak;                // W: 15分休
  row[24] = data.otherBreak;                // Y: 他休憩
  row[25] = data.actualWorkMinutes;         // Z: 実労時間
  row[28] = data.mealService ? '○' : '';           // AC: 食事提供加算
  row[29] = data.absenceSupport ? '○' : '';        // AD: 欠席対応加算
  row[30] = data.visitSupport ? '○' : '';          // AE: 訪問支援加算
  row[31] = data.transportService ? '○' : '';      // AF: 送迎加算

  return row;
}

/**
 * 勤怠データ行をパース
 */
function parseAttendanceRow(row, rowId) {
  return {
    rowId: rowId,
    date: formatDate(row[3]),
    userName: row[4],
    scheduledUse: row[5],
    attendance: row[6],
    morningTask: row[7],
    afternoonTask: row[8],
    userComment: row[9],
    healthCondition: row[10],
    sleepStatus: row[11],
    specialNotes: row[12],
    checkinTime: row[18],
    checkoutTime: row[19],
    lunchBreak: row[20],
    shortBreak: row[22],
    otherBreak: row[24],
    actualWorkMinutes: row[25],
    mealService: row[28] === '○',
    absenceSupport: row[29] === '○',
    visitSupport: row[30] === '○',
    transportService: row[31] === '○'
  };
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
function calculateWorkMinutes(checkinTime, checkoutTime, data) {
  if (!checkinTime || !checkoutTime) return 0;

  const checkin = parseTime(checkinTime);
  const checkout = parseTime(checkoutTime);

  let totalMinutes = (checkout - checkin) / 60000;  // ミリ秒を分に変換

  // 休憩時間を引く
  if (data.lunchBreak) totalMinutes -= parseInt(data.lunchBreak) || 0;
  if (data.shortBreak) totalMinutes -= parseInt(data.shortBreak) || 0;
  if (data.otherBreak) totalMinutes -= parseInt(data.otherBreak) || 0;

  return Math.max(0, Math.round(totalMinutes));
}

/**
 * 時刻文字列をDateオブジェクトに変換
 */
function parseTime(timeStr) {
  const today = new Date();
  const [hours, minutes] = timeStr.split(':').map(Number);
  today.setHours(hours, minutes, 0, 0);
  return today;
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
