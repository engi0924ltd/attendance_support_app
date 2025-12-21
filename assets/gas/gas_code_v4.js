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
  SUPPORT: '支援記録_2025',
  ROSTER: '名簿_2025'
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
    NAME: 1,             // A列: 利用者名
    FURIGANA: 2,         // B列: フリガナ
    STATUS: 3,           // C列: 契約状態
    // 曜日別出欠予定（新規）
    SCHEDULED_MON: 4,    // D列: 出欠（予定）月曜
    SCHEDULED_TUE: 5,    // E列: 出欠（予定）火曜
    SCHEDULED_WED: 6,    // F列: 出欠（予定）水曜
    SCHEDULED_THU: 7,    // G列: 出欠（予定）木曜
    SCHEDULED_FRI: 8,    // H列: 出欠（予定）金曜
    SCHEDULED_SAT: 9,    // I列: 出欠（予定）土曜
    SCHEDULED_SUN: 10    // J列: 出欠（予定）日曜
  },

  // プルダウン列（K〜T列）8〜29行目
  DROPDOWN_COLS: {
    ATTENDANCE: 11,        // K列: 出欠（実績）
    MORNING_TASK: 12,      // L列: 担当業務AM
    AFTERNOON_TASK: 13,    // M列: 担当業務PM
    HEALTH: 14,            // N列: 本日の体調（8〜29行目）
    SLEEP: 15,             // O列: 睡眠状況（8〜29行目）
    CHECKIN_TIME: 16,      // P列: 勤務開始時刻
    CHECKOUT_TIME: 17,     // Q列: 勤務終了時刻
    LUNCH_BREAK: 18,       // R列: 昼休憩
    SHORT_BREAK: 19,       // S列: 15分休憩
    OTHER_BREAK: 20        // T列: 他休憩時間
  },

  // 曜日別出欠予定用プルダウン列（K列、44〜55行目）
  SCHEDULED_WEEKLY_DROPDOWN_COL: 11,  // K列: 曜日別出欠予定の選択肢
  SCHEDULED_WEEKLY_DROPDOWN_START_ROW: 44,
  SCHEDULED_WEEKLY_DROPDOWN_END_ROW: 55,

  // 退勤時プルダウン列（N〜O列）31〜40行目
  CHECKOUT_DROPDOWN_COLS: {
    FATIGUE: 14,           // N列: 疲労感（31〜40行目）
    STRESS: 15             // O列: 心理的負荷（31〜40行目）
  },

  // 職員セクション
  STAFF_HEADER_ROW: 6,
  STAFF_DATA_START_ROW: 8,
  STAFF_DATA_END_ROW: 200,  // 200行まで対応

  STAFF_COLS: {
    NAME: 22,       // V列: 職員名（元P列から+6列）
    ROLE: 23,       // W列: 権限（元Q列から+6列）
    EMAIL: 24,      // X列: メールアドレス（元R列から+6列）
    PASSWORD: 25,   // Y列: パスワード（元S列から+6列）
    JOB_TYPE: 26    // Z列: 職種（元T列から+6列）
  },

  // 名簿用プルダウン選択肢（L〜S列、44〜50行目）
  ROSTER_DROPDOWN_START_ROW: 44,
  ROSTER_DROPDOWN_END_ROW: 50,
  ROSTER_DROPDOWN_COLS: {
    STATUS: 12,           // L列: ステータス（E列用）
    LIFE_PROTECTION: 13,  // M列: 生活保護（T列用）
    DISABILITY_PENSION: 14, // N列: 障がい者手帳年金（U列用）
    DISABILITY_GRADE: 15,   // O列: 障害等級（W列用）
    DISABILITY_TYPE: 16,    // P列: 障害種別（X列用）
    SUPPORT_LEVEL: 17,      // Q列: 障害支援区分（AG列用）
    CONTRACT_TYPE: 18,      // R列: 契約形態（BF列用）
    EMPLOYMENT_SUPPORT: 19  // S列: 定着支援有無（BG列用）
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
  SHORT_BREAK: 22,      // V列: 15分休憩
  OTHER_BREAK: 23,      // W列: 他休憩時間
  WORK_MINUTES: 24,     // X列: 実労時間
  MEAL_SERVICE: 25,     // Y列: 食事提供
  ABSENCE_SUPPORT: 26,  // Z列: 欠席対応
  VISIT_SUPPORT: 27,    // AA列: 訪問支援
  TRANSPORT: 28         // AB列: 送迎
};

// 名簿_2025シートの列構成（A〜BH列：全60列）
const ROSTER_COLS = {
  // 基本情報（A〜H列）
  NUMBER: 1,            // A列: 人数
  NAME: 2,              // B列: 氏名
  NAME_KANA: 3,         // C列: 氏名カナ
  AGE: 4,               // D列: 年齢（自動計算）
  STATUS: 5,            // E列: ステータス
  MOBILE_PHONE: 6,      // F列: 携帯電話番号
  CHATWORK_ID: 7,       // G列: ChatWorkルームID
  MAIL: 8,              // H列: mail

  // 緊急連絡先（I〜L列）
  EMERGENCY_CONTACT1: 9,    // I列: 緊急連絡先 - 連絡先
  EMERGENCY_PHONE1: 10,     // J列: 緊急連絡先 - 電話番号
  EMERGENCY_CONTACT2: 11,   // K列: 緊急連絡先2 - 連絡先
  EMERGENCY_PHONE2: 12,     // L列: 緊急連絡先2 - 電話番号

  // 住所情報（M〜R列）
  POSTAL_CODE: 13,      // M列: 郵便番号
  PREFECTURE: 14,       // N列: 都道府県
  CITY: 15,             // O列: 市区町村
  WARD: 16,             // P列: 政令指定都市区名入力
  ADDRESS: 17,          // Q列: 住所
  ADDRESS2: 18,         // R列: 住所2（転居先など）

  // 詳細情報（S〜AH列）
  BIRTH_DATE: 19,       // S列: 生年月日（西暦）
  LIFE_PROTECTION: 20,  // T列: 生活保護
  DISABILITY_PENSION: 21, // U列: 障がい者手帳年金
  DISABILITY_NUMBER: 22, // V列: 障害者手帳番号
  DISABILITY_GRADE: 23, // W列: 障害等級
  DISABILITY_TYPE: 24,  // X列: 障害種別
  HANDBOOK_VALID: 25,   // Y列: 手帳有効期間
  MUNICIPAL_NUMBER: 26, // Z列: 市区町村番号
  CERTIFICATE_NUMBER: 27, // AA列: 受給者証番号等
  DECISION_PERIOD1: 28, // AB列: 支給決定期間
  DECISION_PERIOD2: 29, // AC列: 支給決定期間
  APPLICABLE_START: 30, // AD列: 適用期間開始日
  APPLICABLE_END: 31,   // AE列: 適用期間有効期限
  SUPPLY_AMOUNT: 32,    // AF列: 支給量
  SUPPORT_LEVEL: 33,    // AG列: 障害支援区分
  USE_START_DATE: 34,   // AH列: 利用開始日

  // 期間計算（AI〜AK列）
  USE_PERIOD: 35,       // AI列: 本日までの利用期間（自動計算）
  INITIAL_ADDITION: 36, // AJ列: 初期加算有効期間（30日）
  PLAN_UPDATE: 37,      // AK列: 個別支援計画書更新日（自動計算）

  // 相談支援事業所（AL〜AN列）
  CONSULTATION_FACILITY: 38,  // AL列: 施設名
  CONSULTATION_STAFF: 39,     // AM列: 担当者名
  CONSULTATION_CONTACT: 40,   // AN列: 連絡先

  // グループホーム（AO〜AQ列）
  GH_FACILITY: 41,      // AO列: 施設名
  GH_STAFF: 42,         // AP列: 担当者名
  GH_CONTACT: 43,       // AQ列: 連絡先

  // その他関係機関（AR〜AT列）
  OTHER_FACILITY: 44,   // AR列: 施設名
  OTHER_STAFF: 45,      // AS列: 担当者名
  OTHER_CONTACT: 46,    // AT列: 連絡先

  // 工賃振込先情報（AU〜AY列）
  BANK_NAME: 47,        // AU列: 銀行名
  BANK_CODE: 48,        // AV列: 金融機関コード
  BRANCH_NAME: 49,      // AW列: 支店名
  BRANCH_CODE: 50,      // AX列: 支店番号
  ACCOUNT_NUMBER: 51,   // AY列: 口座番号

  // 退所・就労情報（AZ〜BH列）
  RESERVED1: 52,        // AZ列: （空白列）
  LEAVE_DATE: 53,       // BA列: 退所日
  LEAVE_REASON: 54,     // BB列: 退所理由
  WORK_NAME: 55,        // BC列: 勤務先 名称
  WORK_CONTACT: 56,     // BD列: 勤務先 連絡先
  WORK_CONTENT: 57,     // BE列: 業務内容
  CONTRACT_TYPE: 58,    // BF列: 契約形態
  EMPLOYMENT_SUPPORT: 59, // BG列: 定着支援 有無
  NOTES: 60             // BH列: 配慮事項
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
    } else if (action.startsWith('attendance/scheduled/')) {
      const date = action.split('/')[2];
      return handleGetScheduledUsers(date);
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
    } else if (action === 'user/list') {
      return handleGetUserList();
    } else if (action === 'user/create') {
      return handleCreateUser(data);
    } else if (action === 'user/update') {
      return handleUpdateUser(data);
    } else if (action === 'user/change-status') {
      return handleChangeUserStatus(data);
    } else if (action === 'user/delete') {
      return handleDeleteUser(data);
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

  const options = {
    // 勤怠用プルダウン
    scheduledUse: [],                                                                                                                                            // 使用しない（scheduledWeeklyを使用）
    attendanceStatus: getColumnOptions(sheet, MASTER_CONFIG.DROPDOWN_COLS.ATTENDANCE),                                                                           // E列: 出欠
    tasks: getColumnOptions(sheet, MASTER_CONFIG.DROPDOWN_COLS.MORNING_TASK),                                                                                    // F列: 担当業務（午前・午後共通）
    healthCondition: getColumnOptions(sheet, MASTER_CONFIG.DROPDOWN_COLS.HEALTH),                                                                                // H列: 本日の体調（8〜29行目）
    sleepStatus: getColumnOptions(sheet, MASTER_CONFIG.DROPDOWN_COLS.SLEEP),                                                                                     // I列: 睡眠状況（8〜29行目）
    fatigue: getColumnOptions(sheet, MASTER_CONFIG.CHECKOUT_DROPDOWN_COLS.FATIGUE, MASTER_CONFIG.CHECKOUT_DROPDOWN_START_ROW, MASTER_CONFIG.CHECKOUT_DROPDOWN_END_ROW),  // H列: 疲労感（31〜40行目）
    stress: getColumnOptions(sheet, MASTER_CONFIG.CHECKOUT_DROPDOWN_COLS.STRESS, MASTER_CONFIG.CHECKOUT_DROPDOWN_START_ROW, MASTER_CONFIG.CHECKOUT_DROPDOWN_END_ROW),    // I列: 心理的負荷（31〜40行目）
    lunchBreak: getTimeListOptions(sheet, MASTER_CONFIG.DROPDOWN_COLS.LUNCH_BREAK, 8, 25),  // R列: 昼休憩（8〜25行目）
    shortBreak: getTimeListOptions(sheet, MASTER_CONFIG.DROPDOWN_COLS.SHORT_BREAK, 8, 25),  // S列: 15分休憩（8〜25行目）
    otherBreak: getTimeListOptions(sheet, MASTER_CONFIG.DROPDOWN_COLS.OTHER_BREAK, 8, 25),  // T列: その他休憩（8〜25行目）
    specialNotes: [],                                                                                                                                             // 特記事項（使用しない）
    breaks: [],                                                                                                                                                   // 休憩時間（使用しない）
    workLocations: [],                                                                                                                                            // 勤務地（使用しない）
    evaluations: [],                                                                                                                                              // 評価項目（使用しない）

    // 曜日別出欠予定用プルダウン（K列、44〜50行目）
    scheduledWeekly: getColumnOptions(sheet, MASTER_CONFIG.SCHEDULED_WEEKLY_DROPDOWN_COL, MASTER_CONFIG.SCHEDULED_WEEKLY_DROPDOWN_START_ROW, MASTER_CONFIG.SCHEDULED_WEEKLY_DROPDOWN_END_ROW), // K列: 曜日別出欠予定

    // 名簿用プルダウン（L〜S列、44〜50行目）
    rosterStatus: getColumnOptions(sheet, MASTER_CONFIG.ROSTER_DROPDOWN_COLS.STATUS, MASTER_CONFIG.ROSTER_DROPDOWN_START_ROW, MASTER_CONFIG.ROSTER_DROPDOWN_END_ROW),                     // L列: ステータス
    lifeProtection: getColumnOptions(sheet, MASTER_CONFIG.ROSTER_DROPDOWN_COLS.LIFE_PROTECTION, MASTER_CONFIG.ROSTER_DROPDOWN_START_ROW, MASTER_CONFIG.ROSTER_DROPDOWN_END_ROW),         // M列: 生活保護
    disabilityPension: getColumnOptions(sheet, MASTER_CONFIG.ROSTER_DROPDOWN_COLS.DISABILITY_PENSION, MASTER_CONFIG.ROSTER_DROPDOWN_START_ROW, MASTER_CONFIG.ROSTER_DROPDOWN_END_ROW),   // N列: 障がい者手帳年金
    disabilityGrade: getColumnOptions(sheet, MASTER_CONFIG.ROSTER_DROPDOWN_COLS.DISABILITY_GRADE, MASTER_CONFIG.ROSTER_DROPDOWN_START_ROW, MASTER_CONFIG.ROSTER_DROPDOWN_END_ROW),       // O列: 障害等級
    disabilityType: getColumnOptions(sheet, MASTER_CONFIG.ROSTER_DROPDOWN_COLS.DISABILITY_TYPE, MASTER_CONFIG.ROSTER_DROPDOWN_START_ROW, MASTER_CONFIG.ROSTER_DROPDOWN_END_ROW),         // P列: 障害種別
    supportLevel: getColumnOptions(sheet, MASTER_CONFIG.ROSTER_DROPDOWN_COLS.SUPPORT_LEVEL, MASTER_CONFIG.ROSTER_DROPDOWN_START_ROW, MASTER_CONFIG.ROSTER_DROPDOWN_END_ROW),             // Q列: 障害支援区分
    contractType: getColumnOptions(sheet, MASTER_CONFIG.ROSTER_DROPDOWN_COLS.CONTRACT_TYPE, MASTER_CONFIG.ROSTER_DROPDOWN_START_ROW, MASTER_CONFIG.ROSTER_DROPDOWN_END_ROW),             // R列: 契約形態
    employmentSupport: getColumnOptions(sheet, MASTER_CONFIG.ROSTER_DROPDOWN_COLS.EMPLOYMENT_SUPPORT, MASTER_CONFIG.ROSTER_DROPDOWN_START_ROW, MASTER_CONFIG.ROSTER_DROPDOWN_END_ROW),   // S列: 定着支援有無

    // 15分刻みの時間リスト（P列・Q列、8〜40行目）
    checkinTimeList: getTimeListOptions(sheet, MASTER_CONFIG.DROPDOWN_COLS.CHECKIN_TIME, 8, 40),   // P列: 勤務開始時刻（8〜40行目）
    checkoutTimeList: getTimeListOptions(sheet, MASTER_CONFIG.DROPDOWN_COLS.CHECKOUT_TIME, 8, 40)  // Q列: 勤務終了時刻（8〜40行目）
  };

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
      options.push(String(value));
    }
  }

  return options;
}

/**
 * 指定列の時間リストを取得（HH:MM形式）
 */
function getTimeListOptions(sheet, col, startRow, endRow) {
  const options = [];

  // 指定範囲から時間を読み取り
  for (let row = startRow; row <= endRow; row++) {
    const value = sheet.getRange(row, col).getValue();

    // 空白はスキップ
    if (value && value !== '') {
      // Dateオブジェクトの場合はHH:MM形式に変換
      if (value instanceof Date) {
        const hours = String(value.getHours()).padStart(2, '0');
        const minutes = String(value.getMinutes()).padStart(2, '0');
        options.push(`${hours}:${minutes}`);
      } else {
        // 文字列の場合はそのまま追加
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

  if (!email) {
    return createErrorResponse('メールアドレスが入力されていません');
  }

  if (!password) {
    return createErrorResponse('パスワードが入力されていません');
  }

  const sheet = getSheet(SHEET_NAMES.MASTER);

  // デバッグ情報を収集
  const debugInfo = [];
  debugInfo.push('検索: ' + email);
  debugInfo.push('列: NAME=V(' + MASTER_CONFIG.STAFF_COLS.NAME + '), EMAIL=X(' + MASTER_CONFIG.STAFF_COLS.EMAIL + '), PASS=Y(' + MASTER_CONFIG.STAFF_COLS.PASSWORD + ')');
  debugInfo.push('範囲: ' + MASTER_CONFIG.STAFF_DATA_START_ROW + '〜' + MASTER_CONFIG.STAFF_DATA_END_ROW + '行');

  // 職員データ行を読み取り
  for (let row = MASTER_CONFIG.STAFF_DATA_START_ROW; row <= MASTER_CONFIG.STAFF_DATA_END_ROW; row++) {
    const staffName = sheet.getRange(row, MASTER_CONFIG.STAFF_COLS.NAME).getValue();
    const staffEmail = sheet.getRange(row, MASTER_CONFIG.STAFF_COLS.EMAIL).getValue();
    const staffPassword = sheet.getRange(row, MASTER_CONFIG.STAFF_COLS.PASSWORD).getValue();

    // データがある行を記録
    if (staffName || staffEmail) {
      debugInfo.push('Row' + row + ': ' + staffName + ' / ' + staffEmail);
    }

    // メールアドレスチェック（前後の空白を削除して比較）
    if (staffEmail && String(staffEmail).trim() === String(email).trim()) {
      if (staffPassword && String(staffPassword).trim() === String(password).trim()) {
        const token = generateToken(email);
        const staffRole = sheet.getRange(row, MASTER_CONFIG.STAFF_COLS.ROLE).getValue();

        return createSuccessResponse({
          staffName: staffName || '',
          email: staffEmail,
          role: staffRole || '支援員',
          token: token
        });
      } else {
        return createErrorResponse('パスワード不一致\n\n' + debugInfo.join('\n'));
      }
    }
  }

  return createErrorResponse('メール未登録\n\n' + debugInfo.join('\n'));
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
    const staffList = [];

    // 8行目から200行目まで走査
    for (let row = MASTER_CONFIG.STAFF_DATA_START_ROW; row <= MASTER_CONFIG.STAFF_DATA_END_ROW; row++) {
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

// === 利用者（ユーザー）管理 ===

/**
 * 名簿_2025シートに利用者データを書き込む
 */
function writeToRosterSheet(rosterSheet, rowNumber, data) {
  const cols = ROSTER_COLS;

  // 基本情報
  if (data.name) rosterSheet.getRange(rowNumber, cols.NAME).setValue(data.name);
  if (data.furigana) rosterSheet.getRange(rowNumber, cols.NAME_KANA).setValue(data.furigana);
  if (data.status) rosterSheet.getRange(rowNumber, cols.STATUS).setValue(data.status);

  // マスタ設定の曜日別出欠予定は名簿には保存しない（マスタ設定のみ）

  // 連絡先情報
  if (data.mobilePhone !== undefined) rosterSheet.getRange(rowNumber, cols.MOBILE_PHONE).setValue(data.mobilePhone || '');
  if (data.chatworkId !== undefined) rosterSheet.getRange(rowNumber, cols.CHATWORK_ID).setValue(data.chatworkId || '');
  if (data.mail !== undefined) rosterSheet.getRange(rowNumber, cols.MAIL).setValue(data.mail || '');
  if (data.emergencyContact1 !== undefined) rosterSheet.getRange(rowNumber, cols.EMERGENCY_CONTACT1).setValue(data.emergencyContact1 || '');
  if (data.emergencyPhone1 !== undefined) rosterSheet.getRange(rowNumber, cols.EMERGENCY_PHONE1).setValue(data.emergencyPhone1 || '');
  if (data.emergencyContact2 !== undefined) rosterSheet.getRange(rowNumber, cols.EMERGENCY_CONTACT2).setValue(data.emergencyContact2 || '');
  if (data.emergencyPhone2 !== undefined) rosterSheet.getRange(rowNumber, cols.EMERGENCY_PHONE2).setValue(data.emergencyPhone2 || '');

  // 住所情報
  if (data.postalCode !== undefined) rosterSheet.getRange(rowNumber, cols.POSTAL_CODE).setValue(data.postalCode || '');
  if (data.prefecture !== undefined) rosterSheet.getRange(rowNumber, cols.PREFECTURE).setValue(data.prefecture || '');
  if (data.city !== undefined) rosterSheet.getRange(rowNumber, cols.CITY).setValue(data.city || '');
  if (data.ward !== undefined) rosterSheet.getRange(rowNumber, cols.WARD).setValue(data.ward || '');
  if (data.address !== undefined) rosterSheet.getRange(rowNumber, cols.ADDRESS).setValue(data.address || '');
  if (data.address2 !== undefined) rosterSheet.getRange(rowNumber, cols.ADDRESS2).setValue(data.address2 || '');

  // 詳細情報
  if (data.birthDate !== undefined) rosterSheet.getRange(rowNumber, cols.BIRTH_DATE).setValue(data.birthDate || '');
  if (data.lifeProtection !== undefined) rosterSheet.getRange(rowNumber, cols.LIFE_PROTECTION).setValue(data.lifeProtection || '');
  if (data.disabilityPension !== undefined) rosterSheet.getRange(rowNumber, cols.DISABILITY_PENSION).setValue(data.disabilityPension || '');
  if (data.disabilityNumber !== undefined) rosterSheet.getRange(rowNumber, cols.DISABILITY_NUMBER).setValue(data.disabilityNumber || '');
  if (data.disabilityGrade !== undefined) rosterSheet.getRange(rowNumber, cols.DISABILITY_GRADE).setValue(data.disabilityGrade || '');
  if (data.disabilityType !== undefined) rosterSheet.getRange(rowNumber, cols.DISABILITY_TYPE).setValue(data.disabilityType || '');
  if (data.handbookValid !== undefined) rosterSheet.getRange(rowNumber, cols.HANDBOOK_VALID).setValue(data.handbookValid || '');
  if (data.municipalNumber !== undefined) rosterSheet.getRange(rowNumber, cols.MUNICIPAL_NUMBER).setValue(data.municipalNumber || '');
  if (data.certificateNumber !== undefined) rosterSheet.getRange(rowNumber, cols.CERTIFICATE_NUMBER).setValue(data.certificateNumber || '');
  if (data.decisionPeriod1 !== undefined) rosterSheet.getRange(rowNumber, cols.DECISION_PERIOD1).setValue(data.decisionPeriod1 || '');
  if (data.decisionPeriod2 !== undefined) rosterSheet.getRange(rowNumber, cols.DECISION_PERIOD2).setValue(data.decisionPeriod2 || '');
  if (data.applicableStart !== undefined) rosterSheet.getRange(rowNumber, cols.APPLICABLE_START).setValue(data.applicableStart || '');
  if (data.applicableEnd !== undefined) rosterSheet.getRange(rowNumber, cols.APPLICABLE_END).setValue(data.applicableEnd || '');
  if (data.supplyAmount !== undefined) rosterSheet.getRange(rowNumber, cols.SUPPLY_AMOUNT).setValue(data.supplyAmount || '');
  if (data.supportLevel !== undefined) rosterSheet.getRange(rowNumber, cols.SUPPORT_LEVEL).setValue(data.supportLevel || '');
  if (data.useStartDate !== undefined) rosterSheet.getRange(rowNumber, cols.USE_START_DATE).setValue(data.useStartDate || '');

  // 期間計算（自動計算列は書き込まない）
  if (data.initialAddition !== undefined) rosterSheet.getRange(rowNumber, cols.INITIAL_ADDITION).setValue(data.initialAddition || '');

  // 相談支援事業所
  if (data.consultationFacility !== undefined) rosterSheet.getRange(rowNumber, cols.CONSULTATION_FACILITY).setValue(data.consultationFacility || '');
  if (data.consultationStaff !== undefined) rosterSheet.getRange(rowNumber, cols.CONSULTATION_STAFF).setValue(data.consultationStaff || '');
  if (data.consultationContact !== undefined) rosterSheet.getRange(rowNumber, cols.CONSULTATION_CONTACT).setValue(data.consultationContact || '');

  // グループホーム
  if (data.ghFacility !== undefined) rosterSheet.getRange(rowNumber, cols.GH_FACILITY).setValue(data.ghFacility || '');
  if (data.ghStaff !== undefined) rosterSheet.getRange(rowNumber, cols.GH_STAFF).setValue(data.ghStaff || '');
  if (data.ghContact !== undefined) rosterSheet.getRange(rowNumber, cols.GH_CONTACT).setValue(data.ghContact || '');

  // その他関係機関
  if (data.otherFacility !== undefined) rosterSheet.getRange(rowNumber, cols.OTHER_FACILITY).setValue(data.otherFacility || '');
  if (data.otherStaff !== undefined) rosterSheet.getRange(rowNumber, cols.OTHER_STAFF).setValue(data.otherStaff || '');
  if (data.otherContact !== undefined) rosterSheet.getRange(rowNumber, cols.OTHER_CONTACT).setValue(data.otherContact || '');

  // 工賃振込先情報
  if (data.bankName !== undefined) rosterSheet.getRange(rowNumber, cols.BANK_NAME).setValue(data.bankName || '');
  if (data.bankCode !== undefined) rosterSheet.getRange(rowNumber, cols.BANK_CODE).setValue(data.bankCode || '');
  if (data.branchName !== undefined) rosterSheet.getRange(rowNumber, cols.BRANCH_NAME).setValue(data.branchName || '');
  if (data.branchCode !== undefined) rosterSheet.getRange(rowNumber, cols.BRANCH_CODE).setValue(data.branchCode || '');
  if (data.accountNumber !== undefined) rosterSheet.getRange(rowNumber, cols.ACCOUNT_NUMBER).setValue(data.accountNumber || '');

  // 退所・就労情報
  if (data.leaveDate !== undefined) rosterSheet.getRange(rowNumber, cols.LEAVE_DATE).setValue(data.leaveDate || '');
  if (data.leaveReason !== undefined) rosterSheet.getRange(rowNumber, cols.LEAVE_REASON).setValue(data.leaveReason || '');
  if (data.workName !== undefined) rosterSheet.getRange(rowNumber, cols.WORK_NAME).setValue(data.workName || '');
  if (data.workContact !== undefined) rosterSheet.getRange(rowNumber, cols.WORK_CONTACT).setValue(data.workContact || '');
  if (data.workContent !== undefined) rosterSheet.getRange(rowNumber, cols.WORK_CONTENT).setValue(data.workContent || '');
  if (data.contractType !== undefined) rosterSheet.getRange(rowNumber, cols.CONTRACT_TYPE).setValue(data.contractType || '');
  if (data.employmentSupport !== undefined) rosterSheet.getRange(rowNumber, cols.EMPLOYMENT_SUPPORT).setValue(data.employmentSupport || '');
  if (data.notes !== undefined) rosterSheet.getRange(rowNumber, cols.NOTES).setValue(data.notes || '');
}

/**
 * 名簿_2025シートから利用者データを削除
 */
function deleteFromRosterSheet(rosterSheet, name) {
  // 名簿_2025シートの3行目から利用者名を検索
  const lastRow = rosterSheet.getLastRow();
  for (let row = 3; row <= lastRow; row++) {
    const rosterName = rosterSheet.getRange(row, ROSTER_COLS.NAME).getValue();
    if (rosterName === name) {
      // 該当行の全列をクリア
      rosterSheet.getRange(row, 1, 1, 60).clearContent();
      return true;
    }
  }
  return false;
}

/**
 * 利用者一覧を取得（全員：契約中 + 退所済み）
 */
function handleGetUserList() {
  try {
    const sheet = getSheet(SHEET_NAMES.MASTER);
    const rosterSheet = getSheet(SHEET_NAMES.ROSTER);
    const userList = [];

    // 8行目から200行目まで走査（空白行で終了）
    for (let row = MASTER_CONFIG.USER_DATA_START_ROW; row <= 200; row++) {
      const name = sheet.getRange(row, MASTER_CONFIG.USER_COLS.NAME).getValue();

      // 空白行に達したら終了
      if (!name || name === '') {
        break;
      }

      const furigana = sheet.getRange(row, MASTER_CONFIG.USER_COLS.FURIGANA).getValue();

      // 名前とフリガナが両方入力されている行のみ取得
      if (furigana) {
        const status = sheet.getRange(row, MASTER_CONFIG.USER_COLS.STATUS).getValue();

        // 曜日別出欠予定を取得
        const scheduledMon = sheet.getRange(row, MASTER_CONFIG.USER_COLS.SCHEDULED_MON).getValue();
        const scheduledTue = sheet.getRange(row, MASTER_CONFIG.USER_COLS.SCHEDULED_TUE).getValue();
        const scheduledWed = sheet.getRange(row, MASTER_CONFIG.USER_COLS.SCHEDULED_WED).getValue();
        const scheduledThu = sheet.getRange(row, MASTER_CONFIG.USER_COLS.SCHEDULED_THU).getValue();
        const scheduledFri = sheet.getRange(row, MASTER_CONFIG.USER_COLS.SCHEDULED_FRI).getValue();
        const scheduledSat = sheet.getRange(row, MASTER_CONFIG.USER_COLS.SCHEDULED_SAT).getValue();
        const scheduledSun = sheet.getRange(row, MASTER_CONFIG.USER_COLS.SCHEDULED_SUN).getValue();

        // 名簿_2025シートから詳細情報を取得
        let rosterRow = -1;
        const rosterLastRow = rosterSheet.getLastRow();

        // 名簿シートで同じ名前の行を探す
        for (let r = 3; r <= rosterLastRow; r++) {
          const rosterName = rosterSheet.getRange(r, ROSTER_COLS.NAME).getValue();
          if (rosterName === name) {
            rosterRow = r;
            break;
          }
        }

        // 基本情報（マスタ設定から）+ 詳細情報（名簿シートから）
        const userObj = {
          // 基本情報
          name: name,
          furigana: furigana,
          status: status || '契約中',
          scheduledMon: scheduledMon || '',
          scheduledTue: scheduledTue || '',
          scheduledWed: scheduledWed || '',
          scheduledThu: scheduledThu || '',
          scheduledFri: scheduledFri || '',
          scheduledSat: scheduledSat || '',
          scheduledSun: scheduledSun || '',
          rowNumber: row
        };

        // 名簿シートにデータがある場合、全60フィールドを追加
        if (rosterRow !== -1) {
          const cols = ROSTER_COLS;

          userObj.rosterRowNumber = rosterRow;

          // 連絡先情報
          userObj.mobilePhone = rosterSheet.getRange(rosterRow, cols.MOBILE_PHONE).getValue() || '';
          userObj.chatworkId = rosterSheet.getRange(rosterRow, cols.CHATWORK_ID).getValue() || '';
          userObj.mail = rosterSheet.getRange(rosterRow, cols.MAIL).getValue() || '';
          userObj.emergencyContact1 = rosterSheet.getRange(rosterRow, cols.EMERGENCY_CONTACT1).getValue() || '';
          userObj.emergencyPhone1 = rosterSheet.getRange(rosterRow, cols.EMERGENCY_PHONE1).getValue() || '';
          userObj.emergencyContact2 = rosterSheet.getRange(rosterRow, cols.EMERGENCY_CONTACT2).getValue() || '';
          userObj.emergencyPhone2 = rosterSheet.getRange(rosterRow, cols.EMERGENCY_PHONE2).getValue() || '';

          // 住所情報
          userObj.postalCode = rosterSheet.getRange(rosterRow, cols.POSTAL_CODE).getValue() || '';
          userObj.prefecture = rosterSheet.getRange(rosterRow, cols.PREFECTURE).getValue() || '';
          userObj.city = rosterSheet.getRange(rosterRow, cols.CITY).getValue() || '';
          userObj.ward = rosterSheet.getRange(rosterRow, cols.WARD).getValue() || '';
          userObj.address = rosterSheet.getRange(rosterRow, cols.ADDRESS).getValue() || '';
          userObj.address2 = rosterSheet.getRange(rosterRow, cols.ADDRESS2).getValue() || '';

          // 詳細情報
          userObj.birthDate = rosterSheet.getRange(rosterRow, cols.BIRTH_DATE).getValue() || '';
          userObj.lifeProtection = rosterSheet.getRange(rosterRow, cols.LIFE_PROTECTION).getValue() || '';
          userObj.disabilityPension = rosterSheet.getRange(rosterRow, cols.DISABILITY_PENSION).getValue() || '';
          userObj.disabilityNumber = rosterSheet.getRange(rosterRow, cols.DISABILITY_NUMBER).getValue() || '';
          userObj.disabilityGrade = rosterSheet.getRange(rosterRow, cols.DISABILITY_GRADE).getValue() || '';
          userObj.disabilityType = rosterSheet.getRange(rosterRow, cols.DISABILITY_TYPE).getValue() || '';
          userObj.handbookValid = rosterSheet.getRange(rosterRow, cols.HANDBOOK_VALID).getValue() || '';
          userObj.municipalNumber = rosterSheet.getRange(rosterRow, cols.MUNICIPAL_NUMBER).getValue() || '';
          userObj.certificateNumber = rosterSheet.getRange(rosterRow, cols.CERTIFICATE_NUMBER).getValue() || '';
          userObj.decisionPeriod1 = rosterSheet.getRange(rosterRow, cols.DECISION_PERIOD1).getValue() || '';
          userObj.decisionPeriod2 = rosterSheet.getRange(rosterRow, cols.DECISION_PERIOD2).getValue() || '';
          userObj.applicableStart = rosterSheet.getRange(rosterRow, cols.APPLICABLE_START).getValue() || '';
          userObj.applicableEnd = rosterSheet.getRange(rosterRow, cols.APPLICABLE_END).getValue() || '';
          userObj.supplyAmount = rosterSheet.getRange(rosterRow, cols.SUPPLY_AMOUNT).getValue() || '';
          userObj.supportLevel = rosterSheet.getRange(rosterRow, cols.SUPPORT_LEVEL).getValue() || '';
          userObj.useStartDate = rosterSheet.getRange(rosterRow, cols.USE_START_DATE).getValue() || '';

          // 期間計算
          userObj.initialAddition = rosterSheet.getRange(rosterRow, cols.INITIAL_ADDITION).getValue() || '';

          // 相談支援事業所
          userObj.consultationFacility = rosterSheet.getRange(rosterRow, cols.CONSULTATION_FACILITY).getValue() || '';
          userObj.consultationStaff = rosterSheet.getRange(rosterRow, cols.CONSULTATION_STAFF).getValue() || '';
          userObj.consultationContact = rosterSheet.getRange(rosterRow, cols.CONSULTATION_CONTACT).getValue() || '';

          // グループホーム
          userObj.ghFacility = rosterSheet.getRange(rosterRow, cols.GH_FACILITY).getValue() || '';
          userObj.ghStaff = rosterSheet.getRange(rosterRow, cols.GH_STAFF).getValue() || '';
          userObj.ghContact = rosterSheet.getRange(rosterRow, cols.GH_CONTACT).getValue() || '';

          // その他関係機関
          userObj.otherFacility = rosterSheet.getRange(rosterRow, cols.OTHER_FACILITY).getValue() || '';
          userObj.otherStaff = rosterSheet.getRange(rosterRow, cols.OTHER_STAFF).getValue() || '';
          userObj.otherContact = rosterSheet.getRange(rosterRow, cols.OTHER_CONTACT).getValue() || '';

          // 工賃振込先情報
          userObj.bankName = rosterSheet.getRange(rosterRow, cols.BANK_NAME).getValue() || '';
          userObj.bankCode = rosterSheet.getRange(rosterRow, cols.BANK_CODE).getValue() || '';
          userObj.branchName = rosterSheet.getRange(rosterRow, cols.BRANCH_NAME).getValue() || '';
          userObj.branchCode = rosterSheet.getRange(rosterRow, cols.BRANCH_CODE).getValue() || '';
          userObj.accountNumber = rosterSheet.getRange(rosterRow, cols.ACCOUNT_NUMBER).getValue() || '';

          // 退所・就労情報
          userObj.leaveDate = rosterSheet.getRange(rosterRow, cols.LEAVE_DATE).getValue() || '';
          userObj.leaveReason = rosterSheet.getRange(rosterRow, cols.LEAVE_REASON).getValue() || '';
          userObj.workName = rosterSheet.getRange(rosterRow, cols.WORK_NAME).getValue() || '';
          userObj.workContact = rosterSheet.getRange(rosterRow, cols.WORK_CONTACT).getValue() || '';
          userObj.workContent = rosterSheet.getRange(rosterRow, cols.WORK_CONTENT).getValue() || '';
          userObj.contractType = rosterSheet.getRange(rosterRow, cols.CONTRACT_TYPE).getValue() || '';
          userObj.employmentSupport = rosterSheet.getRange(rosterRow, cols.EMPLOYMENT_SUPPORT).getValue() || '';
          userObj.notes = rosterSheet.getRange(rosterRow, cols.NOTES).getValue() || '';
        }

        userList.push(userObj);
      }
    }

    return createSuccessResponse({ userList: userList });

  } catch (error) {
    return createErrorResponse('利用者一覧取得エラー: ' + error.message);
  }
}

/**
 * 利用者を新規登録
 */
function handleCreateUser(data) {
  try {
    // バリデーション
    if (!data.name) {
      return createErrorResponse('利用者名を入力してください');
    }
    if (!data.furigana) {
      return createErrorResponse('フリガナを入力してください');
    }
    if (!data.status || (data.status !== '契約中' && data.status !== '退所済み')) {
      return createErrorResponse('契約状態は「契約中」または「退所済み」を指定してください');
    }

    const sheet = getSheet(SHEET_NAMES.MASTER);
    const lastRow = sheet.getLastRow();

    // 同じ名前の利用者が既に存在するかチェック
    for (let row = MASTER_CONFIG.USER_DATA_START_ROW; row <= lastRow; row++) {
      const existingName = sheet.getRange(row, MASTER_CONFIG.USER_COLS.NAME).getValue();
      if (existingName && existingName === data.name) {
        return createErrorResponse('この利用者名は既に登録されています');
      }
    }

    // 空行を探す（A列が空の行）
    let newRow = -1;
    for (let row = MASTER_CONFIG.USER_DATA_START_ROW; row <= lastRow; row++) {
      const existingName = sheet.getRange(row, MASTER_CONFIG.USER_COLS.NAME).getValue();
      if (!existingName || existingName === '') {
        newRow = row;
        break;
      }
    }

    // 空行が見つからなければ最後に追加
    if (newRow === -1) {
      newRow = lastRow + 1;
    }

    // データを書き込む（マスタ設定シート）
    const cols = MASTER_CONFIG.USER_COLS;
    sheet.getRange(newRow, cols.NAME).setValue(data.name);
    sheet.getRange(newRow, cols.FURIGANA).setValue(data.furigana);
    sheet.getRange(newRow, cols.STATUS).setValue(data.status);

    // 曜日別出欠予定を書き込む
    sheet.getRange(newRow, cols.SCHEDULED_MON).setValue(data.scheduledMon || '');
    sheet.getRange(newRow, cols.SCHEDULED_TUE).setValue(data.scheduledTue || '');
    sheet.getRange(newRow, cols.SCHEDULED_WED).setValue(data.scheduledWed || '');
    sheet.getRange(newRow, cols.SCHEDULED_THU).setValue(data.scheduledThu || '');
    sheet.getRange(newRow, cols.SCHEDULED_FRI).setValue(data.scheduledFri || '');
    sheet.getRange(newRow, cols.SCHEDULED_SAT).setValue(data.scheduledSat || '');
    sheet.getRange(newRow, cols.SCHEDULED_SUN).setValue(data.scheduledSun || '');

    // 名簿_2025シートにも書き込む
    const rosterSheet = getSheet(SHEET_NAMES.ROSTER);
    let rosterRow = 3; // 名簿シートは3行目からデータ開始
    const rosterLastRow = rosterSheet.getLastRow();

    // 名簿シートの空行を探す（B列が空の行）
    for (let row = 3; row <= rosterLastRow; row++) {
      const existingName = rosterSheet.getRange(row, ROSTER_COLS.NAME).getValue();
      if (!existingName || existingName === '') {
        rosterRow = row;
        break;
      }
    }

    // 空行が見つからなければ最後に追加
    if (rosterRow === 3 && rosterSheet.getRange(3, ROSTER_COLS.NAME).getValue()) {
      rosterRow = rosterLastRow + 1;
    }

    // 名簿シートにデータを書き込む
    writeToRosterSheet(rosterSheet, rosterRow, data);

    return createSuccessResponse({
      message: '利用者を登録しました',
      user: {
        name: data.name,
        furigana: data.furigana,
        status: data.status,
        scheduledMon: data.scheduledMon || '',
        scheduledTue: data.scheduledTue || '',
        scheduledWed: data.scheduledWed || '',
        scheduledThu: data.scheduledThu || '',
        scheduledFri: data.scheduledFri || '',
        scheduledSat: data.scheduledSat || '',
        scheduledSun: data.scheduledSun || '',
        rowNumber: newRow,
        rosterRowNumber: rosterRow
      }
    });

  } catch (error) {
    return createErrorResponse('利用者登録エラー: ' + error.message);
  }
}

/**
 * 利用者情報を更新
 */
function handleUpdateUser(data) {
  try {
    // バリデーション
    if (!data.rowNumber) {
      return createErrorResponse('行番号が指定されていません');
    }
    if (!data.name) {
      return createErrorResponse('利用者名を入力してください');
    }
    if (!data.furigana) {
      return createErrorResponse('フリガナを入力してください');
    }
    if (!data.status || (data.status !== '契約中' && data.status !== '退所済み')) {
      return createErrorResponse('契約状態は「契約中」または「退所済み」を指定してください');
    }

    const sheet = getSheet(SHEET_NAMES.MASTER);
    const lastRow = sheet.getLastRow();

    // 同じ名前の利用者が既に存在するかチェック（自分自身の行は除外）
    for (let row = MASTER_CONFIG.USER_DATA_START_ROW; row <= lastRow; row++) {
      if (row === data.rowNumber) continue; // 自分自身はスキップ

      const existingName = sheet.getRange(row, MASTER_CONFIG.USER_COLS.NAME).getValue();
      if (existingName && existingName === data.name) {
        return createErrorResponse('この利用者名は既に登録されています');
      }
    }

    // 元の利用者名を取得（名簿シート更新のため）
    const originalName = sheet.getRange(data.rowNumber, MASTER_CONFIG.USER_COLS.NAME).getValue();

    // データを更新（マスタ設定シート）
    const cols = MASTER_CONFIG.USER_COLS;
    sheet.getRange(data.rowNumber, cols.NAME).setValue(data.name);
    sheet.getRange(data.rowNumber, cols.FURIGANA).setValue(data.furigana);
    sheet.getRange(data.rowNumber, cols.STATUS).setValue(data.status);

    // 曜日別出欠予定を更新
    sheet.getRange(data.rowNumber, cols.SCHEDULED_MON).setValue(data.scheduledMon || '');
    sheet.getRange(data.rowNumber, cols.SCHEDULED_TUE).setValue(data.scheduledTue || '');
    sheet.getRange(data.rowNumber, cols.SCHEDULED_WED).setValue(data.scheduledWed || '');
    sheet.getRange(data.rowNumber, cols.SCHEDULED_THU).setValue(data.scheduledThu || '');
    sheet.getRange(data.rowNumber, cols.SCHEDULED_FRI).setValue(data.scheduledFri || '');
    sheet.getRange(data.rowNumber, cols.SCHEDULED_SAT).setValue(data.scheduledSat || '');
    sheet.getRange(data.rowNumber, cols.SCHEDULED_SUN).setValue(data.scheduledSun || '');

    // 名簿_2025シートも更新
    const rosterSheet = getSheet(SHEET_NAMES.ROSTER);
    const rosterLastRow = rosterSheet.getLastRow();

    // 元の名前で名簿シートの行を検索
    let rosterRow = -1;
    for (let row = 3; row <= rosterLastRow; row++) {
      const rosterName = rosterSheet.getRange(row, ROSTER_COLS.NAME).getValue();
      if (rosterName === originalName) {
        rosterRow = row;
        break;
      }
    }

    // 名簿シートの行が見つかった場合のみ更新
    if (rosterRow !== -1) {
      writeToRosterSheet(rosterSheet, rosterRow, data);
    }

    return createSuccessResponse({
      message: '利用者情報を更新しました',
      user: {
        name: data.name,
        furigana: data.furigana,
        status: data.status,
        scheduledMon: data.scheduledMon || '',
        scheduledTue: data.scheduledTue || '',
        scheduledWed: data.scheduledWed || '',
        scheduledThu: data.scheduledThu || '',
        scheduledFri: data.scheduledFri || '',
        scheduledSat: data.scheduledSat || '',
        scheduledSun: data.scheduledSun || '',
        rowNumber: data.rowNumber,
        rosterRowNumber: rosterRow
      }
    });

  } catch (error) {
    return createErrorResponse('利用者更新エラー: ' + error.message);
  }
}

/**
 * 利用者の契約状態を変更
 */
function handleChangeUserStatus(data) {
  try {
    // バリデーション
    if (!data.rowNumber) {
      return createErrorResponse('行番号が指定されていません');
    }
    if (!data.status || (data.status !== '契約中' && data.status !== '退所済み')) {
      return createErrorResponse('契約状態は「契約中」または「退所済み」を指定してください');
    }

    const sheet = getSheet(SHEET_NAMES.MASTER);

    // 元の利用者名を取得（名簿シート更新のため）
    const userName = sheet.getRange(data.rowNumber, MASTER_CONFIG.USER_COLS.NAME).getValue();

    // マスタ設定シートの契約状態を更新
    sheet.getRange(data.rowNumber, MASTER_CONFIG.USER_COLS.STATUS).setValue(data.status);

    // 名簿_2025シートも更新
    const rosterSheet = getSheet(SHEET_NAMES.ROSTER);
    const rosterLastRow = rosterSheet.getLastRow();

    // 元の名前で名簿シートの行を検索
    for (let row = 3; row <= rosterLastRow; row++) {
      const rosterName = rosterSheet.getRange(row, ROSTER_COLS.NAME).getValue();
      if (rosterName === userName) {
        // 名簿シートのステータスも更新
        rosterSheet.getRange(row, ROSTER_COLS.STATUS).setValue(data.status);

        // 退所日も更新（退所済みに変更する場合のみ）
        if (data.status === '退所済み' && data.leaveDate) {
          rosterSheet.getRange(row, ROSTER_COLS.LEAVE_DATE).setValue(data.leaveDate);
        } else if (data.status === '契約中') {
          // 契約中に戻す場合は退所日をクリア
          rosterSheet.getRange(row, ROSTER_COLS.LEAVE_DATE).setValue('');
        }

        break;
      }
    }

    return createSuccessResponse({
      message: '契約状態を更新しました',
      status: data.status,
      leaveDate: data.leaveDate || ''
    });

  } catch (error) {
    return createErrorResponse('契約状態変更エラー: ' + error.message);
  }
}

/**
 * 利用者を削除（行データをクリア）
 */
function handleDeleteUser(data) {
  try {
    // バリデーション
    if (!data.rowNumber) {
      return createErrorResponse('行番号が指定されていません');
    }

    const sheet = getSheet(SHEET_NAMES.MASTER);

    // 削除前に利用者名を取得（名簿シート削除のため）
    const userName = sheet.getRange(data.rowNumber, MASTER_CONFIG.USER_COLS.NAME).getValue();

    // マスタ設定シートのA-J列のデータをクリア
    const cols = MASTER_CONFIG.USER_COLS;
    sheet.getRange(data.rowNumber, cols.NAME).clearContent();
    sheet.getRange(data.rowNumber, cols.FURIGANA).clearContent();
    sheet.getRange(data.rowNumber, cols.STATUS).clearContent();
    sheet.getRange(data.rowNumber, cols.SCHEDULED_MON).clearContent();
    sheet.getRange(data.rowNumber, cols.SCHEDULED_TUE).clearContent();
    sheet.getRange(data.rowNumber, cols.SCHEDULED_WED).clearContent();
    sheet.getRange(data.rowNumber, cols.SCHEDULED_THU).clearContent();
    sheet.getRange(data.rowNumber, cols.SCHEDULED_FRI).clearContent();
    sheet.getRange(data.rowNumber, cols.SCHEDULED_SAT).clearContent();
    sheet.getRange(data.rowNumber, cols.SCHEDULED_SUN).clearContent();

    // 名簿_2025シートからも削除
    const rosterSheet = getSheet(SHEET_NAMES.ROSTER);
    deleteFromRosterSheet(rosterSheet, userName);

    return createSuccessResponse({
      message: '利用者を削除しました'
    });

  } catch (error) {
    return createErrorResponse('利用者削除エラー: ' + error.message);
  }
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

    // D列が空欄の最上行を探す（一括取得で超高速化）
    const lastRow = sheet.getLastRow();
    const maxRow = Math.max(lastRow, 200); // 最低でも200行目までチェック

    // D列を一括取得（API呼び出し1回）
    const dateColumn = sheet.getRange(2, ATTENDANCE_COLS.DATE, maxRow - 1, 1).getValues();

    // メモリ上で空欄行を検索
    let newRow = 2;
    for (let i = 0; i < dateColumn.length; i++) {
      if (dateColumn[i][0] === '' || dateColumn[i][0] === null) {
        newRow = i + 2; // 配列インデックス → 行番号に変換
        break;
      }
    }

    // 空欄行が見つからなかった場合は最後に追加
    if (newRow === 2 && dateColumn[0][0] !== '' && dateColumn[0][0] !== null) {
      newRow = maxRow + 1;
    }

    // マスタ設定シートから曜日別出欠予定を自動取得
    const scheduledAttendance = getUserScheduledAttendance(userName, date);
    const scheduledValue = scheduledAttendance || data.scheduledUse || '';

    // 必要な列のデータを配列として準備（D列〜S列：16列分）
    const rowData = [];
    rowData[0] = date;                          // D列: 日時
    rowData[1] = userName;                      // E列: 利用者名
    rowData[2] = scheduledValue;                // F列: 出欠（予定）
    rowData[3] = data.attendance || '';         // G列: 出欠
    rowData[4] = data.morningTask || '';        // H列: 担当業務AM
    rowData[5] = data.afternoonTask || '';      // I列: 担当業務PM
    rowData[6] = '';                            // J列: 業務連絡
    rowData[7] = data.healthCondition || '';    // K列: 本日の体調
    rowData[8] = data.sleepStatus || '';        // L列: 睡眠状況
    rowData[9] = data.checkinComment || '';     // M列: 出勤時コメント
    rowData[10] = '';                           // N列: 疲労感
    rowData[11] = '';                           // O列: 心理的負荷
    rowData[12] = '';                           // P列: 退勤時コメント
    rowData[13] = '';                           // Q列: （空白列）
    rowData[14] = '';                           // R列: （空白列）
    rowData[15] = data.checkinTime || '';       // S列: 勤務開始時刻

    // D列からS列まで一括入力（API呼び出し1回）
    sheet.getRange(newRow, ATTENDANCE_COLS.DATE, 1, 16).setValues([rowData]);

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

  // 退勤時のデータを配列として準備
  // N列〜P列（疲労感、心理的負荷、退勤時コメント）
  const checkoutData1 = [
    data.fatigue || '',
    data.stress || '',
    data.checkoutComment || ''
  ];

  // T列〜W列（勤務終了時刻、昼休憩、15分休憩、他休憩時間）
  const checkoutData2 = [
    checkoutTime,
    data.lunchBreak || '',
    data.shortBreak || '',
    data.otherBreak || ''
  ];

  // N列〜P列を一括入力（API呼び出し1回）
  sheet.getRange(rowIndex, ATTENDANCE_COLS.FATIGUE, 1, 3).setValues([checkoutData1]);

  // T列〜W列を一括入力（API呼び出し1回）
  sheet.getRange(rowIndex, ATTENDANCE_COLS.CHECKOUT_TIME, 1, 4).setValues([checkoutData2]);

  // X列（実労時間）は関数で自動計算されるため、GAS側での計算・入力は不要
  // S列（開始時刻）、T列（終了時刻）、U/V/W列（休憩）を入力すれば関数が自動計算する

  return createSuccessResponse({
    message: '退勤登録が完了しました'
  });
}

/**
 * 指定日の勤怠一覧取得（一括取得で高速化）
 */
function handleGetDailyAttendance(date) {
  const sheet = getSheet(SHEET_NAMES.ATTENDANCE);
  const lastRow = sheet.getLastRow();

  if (lastRow < 2) {
    return createSuccessResponse({ records: [] });
  }

  // 全データを一括取得（API呼び出しを1回に削減）
  const allData = sheet.getRange(2, 1, lastRow - 1, 28).getValues();
  const records = [];

  // メモリ上でフィルタリング（逆順走査で最新データから検索）
  for (let i = allData.length - 1; i >= 0; i--) {
    const rowData = allData[i];
    const rowDate = formatDate(rowData[ATTENDANCE_COLS.DATE - 1]);

    if (rowDate === date) {
      records.push(parseAttendanceRowFromArray(rowData, i + 2));
    }
  }

  return createSuccessResponse({ records });
}

/**
 * 指定日の出勤予定者一覧を取得（予定と実績をマージ）
 */
function handleGetScheduledUsers(date) {
  try {
    const masterSheet = getSheet(SHEET_NAMES.MASTER);
    const attendanceSheet = getSheet(SHEET_NAMES.ATTENDANCE);
    const dayColumn = getDayOfWeekColumn(date);

    if (!dayColumn) {
      return createErrorResponse('日付の解析に失敗しました');
    }

    // 実際の出勤記録を取得（高速化のため一括取得）
    const lastRow = attendanceSheet.getLastRow();
    const actualAttendance = {};

    if (lastRow >= 2) {
      const allData = attendanceSheet.getRange(2, 1, lastRow - 1, 28).getValues();

      // 指定日の出勤記録を抽出
      for (let i = allData.length - 1; i >= 0; i--) {
        const rowData = allData[i];
        const rowDate = formatDate(rowData[ATTENDANCE_COLS.DATE - 1]);

        if (rowDate === date) {
          const userName = rowData[ATTENDANCE_COLS.USER_NAME - 1];
          actualAttendance[userName] = parseAttendanceRowFromArray(rowData, i + 2);
        }
      }
    }

    // マスタ設定シートから出勤予定者を取得
    const scheduledUsers = [];
    let row = MASTER_CONFIG.USER_DATA_START_ROW;

    while (row <= 1000) {
      const name = masterSheet.getRange(row, MASTER_CONFIG.USER_COLS.NAME).getValue();

      // 空白行に達したら終了
      if (!name || name === '') {
        break;
      }

      const status = masterSheet.getRange(row, MASTER_CONFIG.USER_COLS.STATUS).getValue();
      const scheduledValue = masterSheet.getRange(row, dayColumn).getValue();

      // 契約中かつ出勤予定がある利用者のみ
      if (status === '契約中' && scheduledValue && scheduledValue !== '') {
        const userData = {
          userName: name,
          scheduledAttendance: scheduledValue,
          hasCheckedIn: actualAttendance[name] ? true : false,
          attendance: actualAttendance[name] || null
        };

        scheduledUsers.push(userData);
      }

      row++;
    }

    return createSuccessResponse({ scheduledUsers });

  } catch (error) {
    return createErrorResponse('出勤予定者取得エラー: ' + error.message);
  }
}

/**
 * 勤怠データ行を探す（一括取得で超高速化）
 */
function findAttendanceRow(sheet, date, userName) {
  const lastRow = sheet.getLastRow();

  if (lastRow < 2) {
    return null;
  }

  // D列（日時）とE列（利用者名）を一括取得（API呼び出し1回）
  const dataRange = sheet.getRange(2, ATTENDANCE_COLS.DATE, lastRow - 1, 2).getValues();

  // メモリ上で逆順検索（最新データから）
  for (let i = dataRange.length - 1; i >= 0; i--) {
    const rowDate = formatDate(dataRange[i][0]);
    const rowUserName = dataRange[i][1];

    if (rowDate === date && rowUserName === userName) {
      return i + 2; // 配列インデックス → 行番号に変換
    }
  }

  return null;
}

/**
 * 勤怠データ行をパース（配列版：高速）
 */
function parseAttendanceRowFromArray(rowData, rowNumber) {
  // ヘルパー関数：値を文字列に変換（空白の場合はnull）
  function toStringOrNull(value) {
    if (value === null || value === undefined || value === '') {
      return null;
    }
    return String(value);
  }

  // ヘルパー関数：時刻をHH:mm形式にフォーマット（Date型とString型の両方に対応）
  function formatTimeToHHMM(value) {
    if (value === null || value === undefined || value === '') {
      return null;
    }

    // すでにHH:mm形式の文字列の場合はそのまま返す
    if (typeof value === 'string' && /^\d{1,2}:\d{2}$/.test(value)) {
      return value;
    }

    // Date型の場合はHH:mm形式に変換
    if (value instanceof Date) {
      const hours = String(value.getHours()).padStart(2, '0');
      const minutes = String(value.getMinutes()).padStart(2, '0');
      return `${hours}:${minutes}`;
    }

    // その他の場合は文字列化を試みる
    const valueStr = String(value);
    // HH:mm形式のチェック
    if (/^\d{1,2}:\d{2}$/.test(valueStr)) {
      return valueStr;
    }

    return null;
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
    rowId: rowNumber,
    date: formatDate(rowData[ATTENDANCE_COLS.DATE - 1]),
    userName: toStringOrNull(rowData[ATTENDANCE_COLS.USER_NAME - 1]),
    scheduledUse: toStringOrNull(rowData[ATTENDANCE_COLS.SCHEDULED - 1]),
    attendance: toStringOrNull(rowData[ATTENDANCE_COLS.ATTENDANCE - 1]),
    morningTask: toStringOrNull(rowData[ATTENDANCE_COLS.MORNING_TASK - 1]),
    afternoonTask: toStringOrNull(rowData[ATTENDANCE_COLS.AFTERNOON_TASK - 1]),
    healthCondition: toStringOrNull(rowData[ATTENDANCE_COLS.HEALTH - 1]),
    sleepStatus: toStringOrNull(rowData[ATTENDANCE_COLS.SLEEP - 1]),
    checkinComment: toStringOrNull(rowData[ATTENDANCE_COLS.CHECKIN_COMMENT - 1]),
    fatigue: toStringOrNull(rowData[ATTENDANCE_COLS.FATIGUE - 1]),
    stress: toStringOrNull(rowData[ATTENDANCE_COLS.STRESS - 1]),
    checkoutComment: toStringOrNull(rowData[ATTENDANCE_COLS.CHECKOUT_COMMENT - 1]),
    checkinTime: formatTimeToHHMM(rowData[ATTENDANCE_COLS.CHECKIN_TIME - 1]),
    checkoutTime: formatTimeToHHMM(rowData[ATTENDANCE_COLS.CHECKOUT_TIME - 1]),
    lunchBreak: toStringOrNull(rowData[ATTENDANCE_COLS.LUNCH_BREAK - 1]),
    shortBreak: toStringOrNull(rowData[ATTENDANCE_COLS.SHORT_BREAK - 1]),
    otherBreak: toStringOrNull(rowData[ATTENDANCE_COLS.OTHER_BREAK - 1]),
    actualWorkMinutes: toIntOrNull(rowData[ATTENDANCE_COLS.WORK_MINUTES - 1]),
    mealService: rowData[ATTENDANCE_COLS.MEAL_SERVICE - 1] || false,
    absenceSupport: rowData[ATTENDANCE_COLS.ABSENCE_SUPPORT - 1] || false,
    visitSupport: rowData[ATTENDANCE_COLS.VISIT_SUPPORT - 1] || false,
    transportService: rowData[ATTENDANCE_COLS.TRANSPORT - 1] || false
  };
}

/**
 * 勤怠データ行をパース（シート版：互換性のため残す）
 */
function parseAttendanceRow(sheet, row) {
  // ヘルパー関数：値を文字列に変換（空白の場合はnull）
  function toStringOrNull(value) {
    if (value === null || value === undefined || value === '') {
      return null;
    }
    return String(value);
  }

  // ヘルパー関数：時刻をHH:mm形式にフォーマット（Date型とString型の両方に対応）
  function formatTimeToHHMM(value) {
    if (value === null || value === undefined || value === '') {
      return null;
    }

    // すでにHH:mm形式の文字列の場合はそのまま返す
    if (typeof value === 'string' && /^\d{1,2}:\d{2}$/.test(value)) {
      return value;
    }

    // Date型の場合はHH:mm形式に変換
    if (value instanceof Date) {
      const hours = String(value.getHours()).padStart(2, '0');
      const minutes = String(value.getMinutes()).padStart(2, '0');
      return `${hours}:${minutes}`;
    }

    // その他の場合は文字列化を試みる
    const valueStr = String(value);
    // HH:mm形式のチェック
    if (/^\d{1,2}:\d{2}$/.test(valueStr)) {
      return valueStr;
    }

    return null;
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
    checkinTime: formatTimeToHHMM(sheet.getRange(row, ATTENDANCE_COLS.CHECKIN_TIME).getValue()),
    checkoutTime: formatTimeToHHMM(sheet.getRange(row, ATTENDANCE_COLS.CHECKOUT_TIME).getValue()),
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
 * 日付から曜日列を取得（マスタ設定シートの曜日別出欠予定用）
 */
function getDayOfWeekColumn(dateValue) {
  const date = typeof dateValue === 'string' ? new Date(dateValue) : new Date(dateValue);
  const dayOfWeek = date.getDay(); // 0=日曜, 1=月曜, ..., 6=土曜

  // 曜日に対応する列を返す
  switch (dayOfWeek) {
    case 0: return MASTER_CONFIG.USER_COLS.SCHEDULED_SUN; // 日曜
    case 1: return MASTER_CONFIG.USER_COLS.SCHEDULED_MON; // 月曜
    case 2: return MASTER_CONFIG.USER_COLS.SCHEDULED_TUE; // 火曜
    case 3: return MASTER_CONFIG.USER_COLS.SCHEDULED_WED; // 水曜
    case 4: return MASTER_CONFIG.USER_COLS.SCHEDULED_THU; // 木曜
    case 5: return MASTER_CONFIG.USER_COLS.SCHEDULED_FRI; // 金曜
    case 6: return MASTER_CONFIG.USER_COLS.SCHEDULED_SAT; // 土曜
    default: return null;
  }
}

/**
 * マスタ設定シートから利用者の曜日別出欠予定を取得（一括取得で超高速化）
 */
function getUserScheduledAttendance(userName, dateValue) {
  try {
    const masterSheet = getSheet(SHEET_NAMES.MASTER);
    const dayColumn = getDayOfWeekColumn(dateValue);

    if (!dayColumn) {
      return null;
    }

    // A列（利用者名）と該当曜日列を一括取得（API呼び出し1回）
    // 8行目から200行目までの範囲を取得
    const nameCol = MASTER_CONFIG.USER_COLS.NAME;
    const maxRows = 200;

    // 利用者名列を一括取得
    const namesRange = masterSheet.getRange(MASTER_CONFIG.USER_DATA_START_ROW, nameCol, maxRows, 1).getValues();
    // 該当曜日列を一括取得
    const scheduledRange = masterSheet.getRange(MASTER_CONFIG.USER_DATA_START_ROW, dayColumn, maxRows, 1).getValues();

    // メモリ上で検索
    for (let i = 0; i < namesRange.length; i++) {
      const name = namesRange[i][0];

      // 空白行に達したら終了
      if (!name || name === '') {
        break;
      }

      // 利用者名が一致したら、該当曜日の出欠予定を返す
      if (name === userName) {
        const scheduledValue = scheduledRange[i][0];
        return scheduledValue || null;
      }
    }

    return null; // 利用者が見つからない場合
  } catch (error) {
    return null; // エラーの場合はnullを返す
  }
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
