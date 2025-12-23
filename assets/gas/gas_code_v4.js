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
  ATTENDANCE: '支援記録_2025',  // 【統合】旧：勤怠_2025 → 支援記録_2025に統合
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

  // 出勤時プルダウン選択肢（本日の体調・睡眠状況）
  CHECKIN_DROPDOWN_START_ROW: 8,   // 8行目から出勤時選択肢開始
  CHECKIN_DROPDOWN_END_ROW: 17,    // 17行目まで出勤時選択肢

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

  // 支援記録用プルダウン選択肢（K列、V列、8〜25行目）
  SUPPORT_DROPDOWN_START_ROW: 8,
  SUPPORT_DROPDOWN_END_ROW: 25,
  SUPPORT_DROPDOWN_COLS: {
    WORK_LOCATION: 11,    // K列: 勤務地
    RECORDER: 22          // V列: 記録者（職員名と同じ列）
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

// 【統合】支援記録_2025シートの列構成（勤怠データも含む）
// 旧：勤怠_2025シート（D列〜AB列）は廃止し、支援記録_2025（A列〜AL列）に統合
const SUPPORT_COLS = {
  // A-Y列: 勤怠_2025から自動反映される項目
  DATE: 1,                    // A列: 日時
  USER_NAME: 2,               // B列: 利用者名
  SCHEDULED: 3,               // C列: 出欠（予定）
  ATTENDANCE: 4,              // D列: 出欠
  MORNING_TASK: 5,            // E列: 担当業務AM
  AFTERNOON_TASK: 6,          // F列: 担当業務PM
  WORKPLACE: 7,               // G列: 業務連絡
  HEALTH: 8,                  // H列: 本日の体調
  SLEEP: 9,                   // I列: 睡眠状況
  CHECKIN_COMMENT: 10,        // J列: 出勤時利用者コメント
  FATIGUE: 11,                // K列: 疲労感
  STRESS: 12,                 // L列: 心理的負荷
  CHECKOUT_COMMENT: 13,       // M列: 退勤時利用者コメント
  RESERVE1: 14,               // N列: （予備）
  RESERVE2: 15,               // O列: （予備）
  CHECKIN_TIME: 16,           // P列: 勤務開始時刻
  CHECKOUT_TIME: 17,          // Q列: 勤務終了時刻
  LUNCH_BREAK: 18,            // R列: 昼休憩
  SHORT_BREAK: 19,            // S列: 15分休憩
  OTHER_BREAK: 20,            // T列: 他休憩時間
  WORK_MINUTES: 21,           // U列: 実労時間
  MEAL_SERVICE: 22,           // V列: 食事提供
  ABSENCE_SUPPORT: 23,        // W列: 欠席対応
  VISIT_SUPPORT: 24,          // X列: 訪問支援
  TRANSPORT: 25,              // Y列: 送迎

  // Z-AL列: アプリから手動入力する支援記録項目
  USER_STATUS: 26,            // Z列: 本人の状況/欠勤時対応/施設外評価/在宅評価
  WORK_LOCATION: 27,          // AA列: 勤務地
  RECORDER: 28,               // AB列: 記録者
  RESERVE3: 29,               // AC列: （予備）
  HOME_SUPPORT_EVAL: 30,      // AD列: 在宅支援評価対象
  EXTERNAL_EVAL: 31,          // AE列: 施設外評価対象
  WORK_GOAL: 32,              // AF列: 作業目標
  WORK_EVAL: 33,              // AG列: 勤務評価
  EMPLOYMENT_EVAL: 34,        // AH列: 就労評価（品質・生産性）
  WORK_MOTIVATION: 35,        // AI列: 就労意欲
  COMMUNICATION: 36,          // AJ列: 通信連絡対応
  EVALUATION: 37,             // AK列: 評価
  USER_FEEDBACK: 38           // AL列: 利用者の感想
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
    } else if (action.startsWith('attendance/search/')) {
      // 過去データ検索用（全範囲・遅い）
      const parts = action.split('/');
      const userName = parts[2];
      const date = parts[3];
      return handleSearchUserAttendance(userName, date);
    } else if (action.startsWith('attendance/user/')) {
      // 通常データ取得（直近のみ・高速）
      const parts = action.split('/');
      const userName = parts[2];
      const date = parts[3];
      return handleGetUserAttendance(userName, date);
    } else if (action.startsWith('support/list/')) {
      const date = action.split('/')[2];
      return handleGetSupportRecordList(date);
    } else if (action.startsWith('support/search/')) {
      // 過去データ検索用（全範囲・遅い）
      const parts = action.split('/');
      const date = parts[2];
      const userName = parts[3];
      return handleSearchSupportRecord(date, userName);
    } else if (action.startsWith('support/get/')) {
      // 通常データ取得（直近のみ・高速）
      const parts = action.split('/');
      const date = parts[2];
      const userName = parts[3];
      return handleGetSupportRecord(date, userName);
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
    } else if (action === 'attendance/update') {
      return handleUpdateAttendance(data);
    } else if (action === 'support/upsert') {
      return handleUpsertSupportRecord(data);
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

  // 【最適化】利用者データを一括取得（8行目から最大500行まで）
  const startRow = MASTER_CONFIG.USER_DATA_START_ROW;
  const maxRows = 500; // 最大500行まで検索
  const numCols = 3; // NAME, FURIGANA, STATUS の3列

  // 一括取得（C列、D列、E列）
  const allData = sheet.getRange(startRow, MASTER_CONFIG.USER_COLS.NAME, maxRows, numCols).getValues();

  // データを処理
  for (let i = 0; i < allData.length; i++) {
    const name = allData[i][0]; // C列: NAME
    const furigana = allData[i][1]; // D列: FURIGANA
    const status = allData[i][2]; // E列: STATUS

    // 空白行に達したら終了
    if (!name || name === '') {
      break;
    }

    // 契約中の利用者のみ返す
    if (status === '契約中') {
      users.push({
        name: name,
        furigana: furigana || '',
        status: status
      });
    }
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
    attendanceStatus: getColumnOptions(sheet, MASTER_CONFIG.DROPDOWN_COLS.ATTENDANCE),                                                                           // K列: 出欠
    tasks: getColumnOptions(sheet, MASTER_CONFIG.DROPDOWN_COLS.MORNING_TASK),                                                                                    // L列: 担当業務（午前・午後共通）
    healthCondition: getColumnOptions(sheet, MASTER_CONFIG.DROPDOWN_COLS.HEALTH, MASTER_CONFIG.CHECKIN_DROPDOWN_START_ROW, MASTER_CONFIG.CHECKIN_DROPDOWN_END_ROW),      // N列: 本日の体調（8〜17行目）
    sleepStatus: getColumnOptions(sheet, MASTER_CONFIG.DROPDOWN_COLS.SLEEP, MASTER_CONFIG.CHECKIN_DROPDOWN_START_ROW, MASTER_CONFIG.CHECKIN_DROPDOWN_END_ROW),          // O列: 睡眠状況（8〜17行目）
    fatigue: getColumnOptions(sheet, MASTER_CONFIG.CHECKOUT_DROPDOWN_COLS.FATIGUE, MASTER_CONFIG.CHECKOUT_DROPDOWN_START_ROW, MASTER_CONFIG.CHECKOUT_DROPDOWN_END_ROW),  // N列: 疲労感（31〜40行目）
    stress: getColumnOptions(sheet, MASTER_CONFIG.CHECKOUT_DROPDOWN_COLS.STRESS, MASTER_CONFIG.CHECKOUT_DROPDOWN_START_ROW, MASTER_CONFIG.CHECKOUT_DROPDOWN_END_ROW),    // O列: 心理的負荷（31〜40行目）
    lunchBreak: getTimeListOptions(sheet, MASTER_CONFIG.DROPDOWN_COLS.LUNCH_BREAK, 8, 25),  // R列: 昼休憩（8〜25行目）
    shortBreak: getTimeListOptions(sheet, MASTER_CONFIG.DROPDOWN_COLS.SHORT_BREAK, 8, 25),  // S列: 15分休憩（8〜25行目）
    otherBreak: getTimeListOptions(sheet, MASTER_CONFIG.DROPDOWN_COLS.OTHER_BREAK, 8, 25),  // T列: その他休憩（8〜25行目）
    specialNotes: [],                                                                                                                                             // 特記事項（使用しない）
    breaks: [],                                                                                                                                                   // 休憩時間（使用しない）
    workLocations: getColumnOptions(sheet, MASTER_CONFIG.SUPPORT_DROPDOWN_COLS.WORK_LOCATION, MASTER_CONFIG.SUPPORT_DROPDOWN_START_ROW, MASTER_CONFIG.SUPPORT_DROPDOWN_END_ROW),  // K列: 勤務地（8〜25行目）
    evaluations: [],                                                                                                                                              // 評価項目（使用しない）

    // 曜日別出欠予定用プルダウン（K列、44〜50行目）
    scheduledWeekly: getColumnOptions(sheet, MASTER_CONFIG.SCHEDULED_WEEKLY_DROPDOWN_COL, MASTER_CONFIG.SCHEDULED_WEEKLY_DROPDOWN_START_ROW, MASTER_CONFIG.SCHEDULED_WEEKLY_DROPDOWN_END_ROW), // K列: 曜日別出欠予定

    // 支援記録用プルダウン
    recorders: getColumnOptions(sheet, MASTER_CONFIG.SUPPORT_DROPDOWN_COLS.RECORDER, MASTER_CONFIG.SUPPORT_DROPDOWN_START_ROW, MASTER_CONFIG.SUPPORT_DROPDOWN_END_ROW),  // V列: 記録者（8〜25行目）

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

  // 【最適化】指定範囲を一括取得
  const numRows = end - start + 1;
  const values = sheet.getRange(start, col, numRows, 1).getValues();

  // データを処理
  for (let i = 0; i < values.length; i++) {
    const value = values[i][0];

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

  // 【最適化】指定範囲を一括取得
  const numRows = endRow - startRow + 1;
  const values = sheet.getRange(startRow, col, numRows, 1).getValues();

  // データを処理
  for (let i = 0; i < values.length; i++) {
    const value = values[i][0];

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

  // 【最適化】職員データを一括取得（V列〜Y列: NAME, ROLE, EMAIL, PASSWORD）
  const numRows = MASTER_CONFIG.STAFF_DATA_END_ROW - MASTER_CONFIG.STAFF_DATA_START_ROW + 1;
  const numCols = 4; // V列からY列まで（NAME, ROLE, EMAIL, PASSWORD）
  const allData = sheet.getRange(
    MASTER_CONFIG.STAFF_DATA_START_ROW,
    MASTER_CONFIG.STAFF_COLS.NAME,  // 22列目（V列）から開始
    numRows,
    numCols
  ).getValues();

  // データを検索
  for (let i = 0; i < allData.length; i++) {
    const staffName = allData[i][0];     // V列 (22): NAME
    const staffRole = allData[i][1];     // W列 (23): ROLE
    const staffEmail = allData[i][2];    // X列 (24): EMAIL
    const staffPassword = allData[i][3]; // Y列 (25): PASSWORD

    // メールアドレスチェック（前後の空白を削除して比較）
    if (staffEmail && String(staffEmail).trim() === String(email).trim()) {
      if (staffPassword && String(staffPassword).trim() === String(password).trim()) {
        const token = generateToken(email);

        return createSuccessResponse({
          staffName: staffName || '',
          email: staffEmail,
          role: staffRole || '支援員',
          token: token
        });
      } else {
        return createErrorResponse('パスワードが正しくありません');
      }
    }
  }

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
    const sheet = getSheet(SHEET_NAMES.SUPPORT);
    const date = data.date || formatDate(new Date());
    const userName = data.userName;

    if (!userName) {
      return createErrorResponse('利用者名が指定されていません');
    }

    // 同日の同利用者の記録が既にあるかチェック
    const existingRow = findSupportRow(sheet, date, userName);
    if (existingRow) {
      return createErrorResponse('既に出勤登録されています');
    }

    // 【統合】A列（日時）が空欄の最上行を探す（一括取得で超高速化）
    const lastRow = sheet.getLastRow();
    const maxRow = Math.max(lastRow, 200); // 最低でも200行目までチェック

    // A列を一括取得（API呼び出し1回）
    const dateColumn = sheet.getRange(2, SUPPORT_COLS.DATE, maxRow - 1, 1).getValues();

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

    // 【統合】支援記録シートのA列〜P列にデータを書き込み
    const rowData = [
      date,                          // A列: 日時
      userName,                      // B列: 利用者名
      scheduledValue,                // C列: 出欠（予定）
      data.attendance || '',         // D列: 出欠
      data.morningTask || '',        // E列: 担当業務AM
      data.afternoonTask || '',      // F列: 担当業務PM
      '',                            // G列: 業務連絡
      data.healthCondition || '',    // H列: 本日の体調
      data.sleepStatus || '',        // I列: 睡眠状況
      data.checkinComment || '',     // J列: 出勤時コメント
      '',                            // K列: 疲労感
      '',                            // L列: 心理的負荷
      '',                            // M列: 退勤時コメント
      '',                            // N列: （予備）
      '',                            // O列: （予備）
      data.checkinTime || ''         // P列: 勤務開始時刻
    ];

    // A列〜P列を一括入力（API呼び出し1回）
    sheet.getRange(newRow, SUPPORT_COLS.DATE, 1, 16).setValues([rowData]);

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
  const sheet = getSheet(SHEET_NAMES.SUPPORT);
  const date = data.date;
  const userName = data.userName;
  const checkoutTime = data.checkoutTime;

  const rowIndex = findSupportRow(sheet, date, userName);

  if (!rowIndex) {
    return createErrorResponse('出勤記録が見つかりません');
  }

  // 【重要】実労時間を計算（数式の代わりに値として保存）
  const checkinTime = sheet.getRange(rowIndex, SUPPORT_COLS.CHECKIN_TIME).getValue();
  const workMinutes = calculateWorkMinutes(
    checkinTime,
    checkoutTime,
    data.lunchBreak || '',
    data.shortBreak || '',
    data.otherBreak || ''
  );

  // 【統合】K列〜U列に退勤データを一括書き込み（11列）
  const checkoutData = [
    data.fatigue || '',         // K列: 疲労感
    data.stress || '',          // L列: 心理的負荷
    data.checkoutComment || '', // M列: 退勤時コメント
    '',                         // N列: 予備
    '',                         // O列: 予備
    checkinTime,                // P列: 勤務開始時刻（既存値を保持）
    checkoutTime,               // Q列: 勤務終了時刻
    data.lunchBreak || '',      // R列: 昼休憩
    data.shortBreak || '',      // S列: 15分休憩
    data.otherBreak || '',      // T列: 他休憩時間
    workMinutes                 // U列: 実労時間
  ];

  // K列〜U列を一括入力（11列）
  sheet.getRange(rowIndex, SUPPORT_COLS.FATIGUE, 1, 11).setValues([checkoutData]);

  return createSuccessResponse({
    message: '退勤登録が完了しました'
  });
}

/**
 * 指定日の勤怠一覧取得（一括取得で高速化）
 */
function handleGetDailyAttendance(date) {
  const sheet = getSheet(SHEET_NAMES.SUPPORT);

  // 【重要】実データの最下行を取得（空白行・数式のみの行を除外）
  const actualLastRow = findActualLastRow(sheet, SUPPORT_COLS.USER_NAME);

  if (actualLastRow < 2) {
    return createSuccessResponse({ records: [] });
  }

  // 【高速化】実データの最下行から上に最大100行のみ検索
  const maxSearchRows = Math.min(actualLastRow - 1, 100);
  const startRow = Math.max(2, actualLastRow - maxSearchRows + 1);
  const searchData = sheet.getRange(startRow, SUPPORT_COLS.DATE, maxSearchRows, 2).getValues();
  const targetRows = [];

  let emptyRowCount = 0;
  const maxEmptyRows = 5; // 連続5行空白で終了

  // 空白行をスキップして対象行を特定（逆順）
  for (let i = searchData.length - 1; i >= 0; i--) {
    const rowUserName = searchData[i][1];

    // 利用者名が空白の行はスキップ（数式だけの行を除外）
    if (!rowUserName || rowUserName === '') {
      emptyRowCount++;
      if (emptyRowCount >= maxEmptyRows) {
        break;
      }
      continue;
    }

    emptyRowCount = 0;
    const rowDate = formatDate(searchData[i][0]);
    if (rowDate === date) {
      targetRows.push(startRow + i);
    }
  }

  // 対象行のみ全カラムを取得
  const records = [];
  for (const rowNumber of targetRows) {
    const rowData = sheet.getRange(rowNumber, 1, 1, 38).getValues()[0];
    records.push(parseAttendanceRowFromArray(rowData, rowNumber));
  }

  return createSuccessResponse({ records });
}

/**
 * 特定利用者の特定日の勤怠データを取得（直近データのみ・高速）
 */
function handleGetUserAttendance(userName, date) {
  try {
    const sheet = getSheet(SHEET_NAMES.SUPPORT);

    // 【重要】実データの最下行を取得（空白行・数式のみの行を除外）
    const actualLastRow = findActualLastRow(sheet, SUPPORT_COLS.USER_NAME);

    if (actualLastRow < 2) {
      return createSuccessResponse({ record: null });
    }

    // 【高速化】実データの最下行から上に最大100行のみ検索
    const maxSearchRows = Math.min(actualLastRow - 1, 100);
    const startRow = Math.max(2, actualLastRow - maxSearchRows + 1);
    const searchData = sheet.getRange(startRow, SUPPORT_COLS.DATE, maxSearchRows, 2).getValues();

    let emptyRowCount = 0;
    const maxEmptyRows = 5; // 連続5行空白で早期終了

    // 下から上に検索（逆順）
    for (let i = searchData.length - 1; i >= 0; i--) {
      const rowUserName = searchData[i][1];

      // 利用者名が空白の行はスキップ
      if (!rowUserName || rowUserName === '') {
        emptyRowCount++;
        if (emptyRowCount >= maxEmptyRows) {
          break; // 連続空白行が多いので終了
        }
        continue;
      }

      emptyRowCount = 0; // データあり、カウントリセット
      const rowDate = formatDate(searchData[i][0]);

      if (rowDate === date && rowUserName === userName) {
        // 見つかった行のみ全カラム（28列）を取得
        const rowNumber = startRow + i;
        const rowData = sheet.getRange(rowNumber, 1, 1, 38).getValues()[0];
        const record = parseAttendanceRowFromArray(rowData, rowNumber);
        return createSuccessResponse({ record });
      }
    }

    return createSuccessResponse({ record: null });
  } catch (error) {
    return createErrorResponse('勤怠データ取得エラー: ' + error.message);
  }
}

/**
 * 特定利用者の特定日の勤怠データを全範囲検索（過去データ用・遅い）
 */
function handleSearchUserAttendance(userName, date) {
  try {
    const sheet = getSheet(SHEET_NAMES.SUPPORT);
    const lastRow = sheet.getLastRow();

    if (lastRow < 2) {
      return createSuccessResponse({ record: null });
    }

    // 全範囲検索（遅いが過去データも取得可能）
    const searchData = sheet.getRange(2, SUPPORT_COLS.DATE, lastRow - 1, 2).getValues();

    // 上から順に検索、空白行はスキップ
    for (let i = 0; i < searchData.length; i++) {
      const rowUserName = searchData[i][1];

      // 利用者名が空白の行はスキップ
      if (!rowUserName || rowUserName === '') {
        continue;
      }

      const rowDate = formatDate(searchData[i][0]);

      if (rowDate === date && rowUserName === userName) {
        // 見つかった行のみ全カラム（28列）を取得
        const rowNumber = i + 2;
        const rowData = sheet.getRange(rowNumber, 1, 1, 38).getValues()[0];
        const record = parseAttendanceRowFromArray(rowData, rowNumber);
        return createSuccessResponse({ record });
      }
    }

    return createSuccessResponse({ record: null });
  } catch (error) {
    return createErrorResponse('勤怠データ検索エラー: ' + error.message);
  }
}

/**
 * 指定日の出勤予定者一覧を取得（空白行除外＋一括取得で超高速化）
 */
function handleGetScheduledUsers(date) {
  try {
    const masterSheet = getSheet(SHEET_NAMES.MASTER);
    const attendanceSheet = getSheet(SHEET_NAMES.SUPPORT);
    const dayColumn = getDayOfWeekColumn(date);

    if (!dayColumn) {
      return createErrorResponse('日付の解析に失敗しました');
    }

    // 勤怠シートから実際の出勤記録を取得
    // 【重要】実データの最下行を取得（空白行・数式のみの行を除外）
    const actualLastRow = findActualLastRow(attendanceSheet, SUPPORT_COLS.USER_NAME);
    const actualAttendance = {};

    if (actualLastRow >= 2) {
      // 【高速化】実データの最下行から上に最大100行のみ検索
      const maxSearchRows = Math.min(actualLastRow - 1, 100);
      const startRow = Math.max(2, actualLastRow - maxSearchRows + 1);
      const searchData = attendanceSheet.getRange(startRow, SUPPORT_COLS.DATE, maxSearchRows, 2).getValues();

      // 指定日のデータを特定、空白行はスキップ
      const targetRows = [];
      let emptyRowCount = 0;
      const maxEmptyRows = 5;

      for (let i = searchData.length - 1; i >= 0; i--) {
        const rowUserName = searchData[i][1];

        // 利用者名が空白の行はスキップ（数式だけの行を除外）
        if (!rowUserName || rowUserName === '') {
          emptyRowCount++;
          if (emptyRowCount >= maxEmptyRows) {
            break;
          }
          continue;
        }

        emptyRowCount = 0;
        const rowDate = formatDate(searchData[i][0]);
        if (rowDate === date) {
          targetRows.push(startRow + i);
        }
      }

      // 対象行のみ全カラムを取得
      for (const rowNumber of targetRows) {
        const rowData = attendanceSheet.getRange(rowNumber, 1, 1, 38).getValues()[0];
        const userName = rowData[SUPPORT_COLS.USER_NAME - 1];
        actualAttendance[userName] = parseAttendanceRowFromArray(rowData, rowNumber);
      }
    }

    // 【重要】マスタシートを一括取得（1行ずつ取得しない）
    const masterDataRange = masterSheet.getDataRange();
    const masterLastRow = masterDataRange.getLastRow();
    const scheduledUsers = [];

    if (masterLastRow >= MASTER_CONFIG.USER_DATA_START_ROW) {
      // 必要な列だけ一括取得（名前、ステータス、曜日列）
      const startRow = MASTER_CONFIG.USER_DATA_START_ROW;
      const numRows = masterLastRow - startRow + 1;
      const masterData = masterSheet.getRange(startRow, 1, numRows, dayColumn).getValues();

      for (let i = 0; i < masterData.length; i++) {
        const name = masterData[i][MASTER_CONFIG.USER_COLS.NAME - 1];

        // 空白行に達したら終了
        if (!name || name === '') {
          break;
        }

        const status = masterData[i][MASTER_CONFIG.USER_COLS.STATUS - 1];
        const scheduledValue = masterData[i][dayColumn - 1];

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
      }
    }

    return createSuccessResponse({ scheduledUsers });

  } catch (error) {
    return createErrorResponse('出勤予定者取得エラー: ' + error.message);
  }
}

/**
 * 勤怠データ行を探す（空白行スキップで超高速化）
 */
function findSupportRow(sheet, date, userName) {
  // 【重要】実データの最下行を取得（空白行・数式のみの行を除外）
  const actualLastRow = findActualLastRow(sheet, SUPPORT_COLS.USER_NAME);

  if (actualLastRow < 2) {
    return null;
  }

  // 【高速化】実データの最下行から上に最大100行のみ検索
  const maxSearchRows = Math.min(actualLastRow - 1, 100);
  const startRow = Math.max(2, actualLastRow - maxSearchRows + 1);
  const searchData = sheet.getRange(startRow, SUPPORT_COLS.DATE, maxSearchRows, 2).getValues();

  let emptyRowCount = 0;
  const maxEmptyRows = 5; // 連続5行空白で終了

  // 下から上に検索、空白行はスキップ
  for (let i = searchData.length - 1; i >= 0; i--) {
    const rowUserName = searchData[i][1];

    // 利用者名が空白の行はスキップ（数式だけの行を除外）
    if (!rowUserName || rowUserName === '') {
      emptyRowCount++;
      if (emptyRowCount >= maxEmptyRows) {
        break;
      }
      continue;
    }

    emptyRowCount = 0;
    const rowDate = formatDate(searchData[i][0]);

    if (rowDate === date && rowUserName === userName) {
      return startRow + i; // 配列インデックス → 行番号に変換
    }
  }

  return null;
}

/**
 * 勤怠データを更新（支援者用）- 一括更新で高速化
 */
function handleUpdateAttendance(data) {
  try {
    const sheet = getSheet(SHEET_NAMES.SUPPORT);
    const date = data.date;
    const userName = data.userName;

    // 既存の勤怠データを検索
    const rowIndex = findSupportRow(sheet, date, userName);

    if (!rowIndex) {
      return createErrorResponse('勤怠データが見つかりません');
    }

    // 【高速化】既存の行データを一括取得（38列まで取得）
    const rowData = sheet.getRange(rowIndex, 1, 1, 38).getValues()[0];

    // 更新する項目のみ変更（配列のインデックスは0始まりなので-1）
    if (data.attendanceStatus !== undefined) {
      rowData[SUPPORT_COLS.ATTENDANCE - 1] = data.attendanceStatus || '';
    }
    if (data.checkinTime !== undefined) {
      rowData[SUPPORT_COLS.CHECKIN_TIME - 1] = data.checkinTime || '';
    }
    if (data.checkoutTime !== undefined) {
      rowData[SUPPORT_COLS.CHECKOUT_TIME - 1] = data.checkoutTime || '';
    }
    if (data.lunchBreak !== undefined) {
      rowData[SUPPORT_COLS.LUNCH_BREAK - 1] = data.lunchBreak || '';
    }
    if (data.shortBreak !== undefined) {
      rowData[SUPPORT_COLS.SHORT_BREAK - 1] = data.shortBreak || '';
    }
    if (data.otherBreak !== undefined) {
      rowData[SUPPORT_COLS.OTHER_BREAK - 1] = data.otherBreak || '';
    }

    // 【重要】時刻や休憩時間が更新された場合、実労時間を再計算
    if (data.checkinTime !== undefined || data.checkoutTime !== undefined ||
        data.lunchBreak !== undefined || data.shortBreak !== undefined || data.otherBreak !== undefined) {
      const workMinutes = calculateWorkMinutes(
        rowData[SUPPORT_COLS.CHECKIN_TIME - 1],
        rowData[SUPPORT_COLS.CHECKOUT_TIME - 1],
        rowData[SUPPORT_COLS.LUNCH_BREAK - 1],
        rowData[SUPPORT_COLS.SHORT_BREAK - 1],
        rowData[SUPPORT_COLS.OTHER_BREAK - 1]
      );
      rowData[SUPPORT_COLS.WORK_MINUTES - 1] = workMinutes;
    }

    // 【統合】一括で書き込み（API呼び出し1回）
    sheet.getRange(rowIndex, 1, 1, 38).setValues([rowData]);

    return createSuccessResponse({
      message: '勤怠データを更新しました',
      rowId: rowIndex
    });
  } catch (error) {
    return createErrorResponse('勤怠データ更新エラー: ' + error.message);
  }
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
    date: formatDate(rowData[SUPPORT_COLS.DATE - 1]),
    userName: toStringOrNull(rowData[SUPPORT_COLS.USER_NAME - 1]),
    scheduledUse: toStringOrNull(rowData[SUPPORT_COLS.SCHEDULED - 1]),
    attendance: toStringOrNull(rowData[SUPPORT_COLS.ATTENDANCE - 1]),
    morningTask: toStringOrNull(rowData[SUPPORT_COLS.MORNING_TASK - 1]),
    afternoonTask: toStringOrNull(rowData[SUPPORT_COLS.AFTERNOON_TASK - 1]),
    healthCondition: toStringOrNull(rowData[SUPPORT_COLS.HEALTH - 1]),
    sleepStatus: toStringOrNull(rowData[SUPPORT_COLS.SLEEP - 1]),
    checkinComment: toStringOrNull(rowData[SUPPORT_COLS.CHECKIN_COMMENT - 1]),
    fatigue: toStringOrNull(rowData[SUPPORT_COLS.FATIGUE - 1]),
    stress: toStringOrNull(rowData[SUPPORT_COLS.STRESS - 1]),
    checkoutComment: toStringOrNull(rowData[SUPPORT_COLS.CHECKOUT_COMMENT - 1]),
    checkinTime: formatTimeToHHMM(rowData[SUPPORT_COLS.CHECKIN_TIME - 1]),
    checkoutTime: formatTimeToHHMM(rowData[SUPPORT_COLS.CHECKOUT_TIME - 1]),
    lunchBreak: toStringOrNull(rowData[SUPPORT_COLS.LUNCH_BREAK - 1]),
    shortBreak: toStringOrNull(rowData[SUPPORT_COLS.SHORT_BREAK - 1]),
    otherBreak: toStringOrNull(rowData[SUPPORT_COLS.OTHER_BREAK - 1]),
    actualWorkMinutes: toIntOrNull(rowData[SUPPORT_COLS.WORK_MINUTES - 1]),
    mealService: rowData[SUPPORT_COLS.MEAL_SERVICE - 1] || false,
    absenceSupport: rowData[SUPPORT_COLS.ABSENCE_SUPPORT - 1] || false,
    visitSupport: rowData[SUPPORT_COLS.VISIT_SUPPORT - 1] || false,
    transportService: rowData[SUPPORT_COLS.TRANSPORT - 1] || false
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
    date: formatDate(sheet.getRange(row, SUPPORT_COLS.DATE).getValue()),
    userName: toStringOrNull(sheet.getRange(row, SUPPORT_COLS.USER_NAME).getValue()),
    scheduledUse: toStringOrNull(sheet.getRange(row, SUPPORT_COLS.SCHEDULED).getValue()),
    attendance: toStringOrNull(sheet.getRange(row, SUPPORT_COLS.ATTENDANCE).getValue()),
    morningTask: toStringOrNull(sheet.getRange(row, SUPPORT_COLS.MORNING_TASK).getValue()),
    afternoonTask: toStringOrNull(sheet.getRange(row, SUPPORT_COLS.AFTERNOON_TASK).getValue()),
    healthCondition: toStringOrNull(sheet.getRange(row, SUPPORT_COLS.HEALTH).getValue()),
    sleepStatus: toStringOrNull(sheet.getRange(row, SUPPORT_COLS.SLEEP).getValue()),
    checkinComment: toStringOrNull(sheet.getRange(row, SUPPORT_COLS.CHECKIN_COMMENT).getValue()),
    fatigue: toStringOrNull(sheet.getRange(row, SUPPORT_COLS.FATIGUE).getValue()),
    stress: toStringOrNull(sheet.getRange(row, SUPPORT_COLS.STRESS).getValue()),
    checkoutComment: toStringOrNull(sheet.getRange(row, SUPPORT_COLS.CHECKOUT_COMMENT).getValue()),
    checkinTime: formatTimeToHHMM(sheet.getRange(row, SUPPORT_COLS.CHECKIN_TIME).getValue()),
    checkoutTime: formatTimeToHHMM(sheet.getRange(row, SUPPORT_COLS.CHECKOUT_TIME).getValue()),
    lunchBreak: toStringOrNull(sheet.getRange(row, SUPPORT_COLS.LUNCH_BREAK).getValue()),
    shortBreak: toStringOrNull(sheet.getRange(row, SUPPORT_COLS.SHORT_BREAK).getValue()),
    otherBreak: toStringOrNull(sheet.getRange(row, SUPPORT_COLS.OTHER_BREAK).getValue()),
    actualWorkMinutes: toIntOrNull(sheet.getRange(row, SUPPORT_COLS.WORK_MINUTES).getValue()),
    mealService: sheet.getRange(row, SUPPORT_COLS.MEAL_SERVICE).getValue() || false,
    absenceSupport: sheet.getRange(row, SUPPORT_COLS.ABSENCE_SUPPORT).getValue() || false,
    visitSupport: sheet.getRange(row, SUPPORT_COLS.VISIT_SUPPORT).getValue() || false,
    transportService: sheet.getRange(row, SUPPORT_COLS.TRANSPORT).getValue() || false
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

// === 支援記録API ===

/**
 * 指定日・利用者の支援記録を取得（直近データのみ・高速）
 */
function handleGetSupportRecord(date, userName) {
  try {
    const supportSheet = getSheet(SHEET_NAMES.SUPPORT);

    // 【重要】実データの最下行を取得（空白行・数式のみの行を除外）
    const actualLastRow = findActualLastRow(supportSheet, SUPPORT_COLS.USER_NAME);

    if (actualLastRow < 2) {
      return createSuccessResponse({ record: null });
    }

    // 【高速化】実データの最下行から上に最大100行のみ検索
    const maxSearchRows = Math.min(actualLastRow - 1, 100);
    const startRow = Math.max(2, actualLastRow - maxSearchRows + 1);
    const searchData = supportSheet.getRange(startRow, SUPPORT_COLS.DATE, maxSearchRows, 2).getValues();

    let emptyRowCount = 0;
    const maxEmptyRows = 5; // 連続5行空白で早期終了

    // 下から上に検索（逆順）
    for (let i = searchData.length - 1; i >= 0; i--) {
      const rowUserName = searchData[i][1];

      // 利用者名が空白の行はスキップ
      if (!rowUserName || rowUserName === '') {
        emptyRowCount++;
        if (emptyRowCount >= maxEmptyRows) {
          break; // 連続空白行が多いので終了
        }
        continue;
      }

      emptyRowCount = 0; // データあり、カウントリセット
      const rowDate = formatDate(searchData[i][0]);

      if (rowDate === date && rowUserName === userName) {
        // 見つかった行のみ全カラム（38列）を取得
        const rowNumber = startRow + i;
        const rowData = supportSheet.getRange(rowNumber, 1, 1, 38).getValues()[0];
        const record = parseSupportRecordFromArray(rowData, rowNumber);
        return createSuccessResponse({ record });
      }
    }

    return createSuccessResponse({ record: null });
  } catch (error) {
    return createErrorResponse('支援記録取得エラー: ' + error.message);
  }
}

/**
 * 指定日・利用者の支援記録を全範囲検索（過去データ用・遅い）
 */
function handleSearchSupportRecord(date, userName) {
  try {
    const supportSheet = getSheet(SHEET_NAMES.SUPPORT);
    const lastRow = supportSheet.getLastRow();

    if (lastRow < 2) {
      return createSuccessResponse({ record: null });
    }

    // 全範囲検索（遅いが過去データも取得可能）
    const searchData = supportSheet.getRange(2, SUPPORT_COLS.DATE, lastRow - 1, 2).getValues();

    // 上から順に検索、空白行はスキップ
    for (let i = 0; i < searchData.length; i++) {
      const rowUserName = searchData[i][1];

      // 利用者名が空白の行はスキップ
      if (!rowUserName || rowUserName === '') {
        continue;
      }

      const rowDate = formatDate(searchData[i][0]);

      if (rowDate === date && rowUserName === userName) {
        // 見つかった行のみ全カラム（38列）を取得
        const rowNumber = i + 2;
        const rowData = supportSheet.getRange(rowNumber, 1, 1, 38).getValues()[0];
        const record = parseSupportRecordFromArray(rowData, rowNumber);
        return createSuccessResponse({ record });
      }
    }

    return createSuccessResponse({ record: null });
  } catch (error) {
    return createErrorResponse('支援記録検索エラー: ' + error.message);
  }
}

/**
 * 指定日の支援記録一覧を取得
 */
function handleGetSupportRecordList(date) {
  try {
    const supportSheet = getSheet(SHEET_NAMES.SUPPORT);

    // 【重要】実データの最下行を取得（空白行・数式のみの行を除外）
    const actualLastRow = findActualLastRow(supportSheet, SUPPORT_COLS.USER_NAME);

    if (actualLastRow < 2) {
      return createSuccessResponse({ records: [] });
    }

    // 【高速化】実データの最下行から上に最大100行のみ検索
    const maxSearchRows = Math.min(actualLastRow - 1, 100);
    const startRow = Math.max(2, actualLastRow - maxSearchRows + 1);
    const searchData = supportSheet.getRange(startRow, SUPPORT_COLS.DATE, maxSearchRows, 2).getValues();
    const targetRows = [];

    let emptyRowCount = 0;
    const maxEmptyRows = 5; // 連続5行空白で終了

    // 空白行をスキップして対象行を特定（逆順）
    for (let i = searchData.length - 1; i >= 0; i--) {
      const rowUserName = searchData[i][1];

      // 利用者名が空白の行はスキップ（数式だけの行を除外）
      if (!rowUserName || rowUserName === '') {
        emptyRowCount++;
        if (emptyRowCount >= maxEmptyRows) {
          break;
        }
        continue;
      }

      emptyRowCount = 0;
      const rowDate = formatDate(searchData[i][0]);
      if (rowDate === date) {
        targetRows.push(startRow + i);
      }
    }

    // 対象行のみ全カラムを取得
    const records = [];
    for (const rowNumber of targetRows) {
      const rowData = supportSheet.getRange(rowNumber, 1, 1, 38).getValues()[0];
      records.push(parseSupportRecordFromArray(rowData, rowNumber));
    }

    return createSuccessResponse({ records });
  } catch (error) {
    return createErrorResponse('支援記録一覧取得エラー: ' + error.message);
  }
}

/**
 * 支援記録を作成または更新
 */
function handleUpsertSupportRecord(data) {
  try {
    const supportSheet = getSheet(SHEET_NAMES.SUPPORT);
    const attendanceSheet = getSheet(SHEET_NAMES.SUPPORT);
    const date = data.date;
    const userName = data.userName;

    // 既存の支援記録を検索
    const existingRow = findSupportRecordRow(supportSheet, date, userName);

    // 勤怠データを取得（A-Y列用）
    const attendanceData = getAttendanceDataForSupport(attendanceSheet, date, userName);

    if (!attendanceData) {
      return createErrorResponse('勤怠データが見つかりません');
    }

    // A-Y列のデータ（勤怠から）
    const baseData = [
      attendanceData.date,              // A列: 日時
      attendanceData.userName,          // B列: 利用者名
      attendanceData.scheduled,         // C列: 出欠（予定）
      attendanceData.attendance,        // D列: 出欠
      attendanceData.morningTask,       // E列: 担当業務AM
      attendanceData.afternoonTask,     // F列: 担当業務PM
      attendanceData.workplace,         // G列: 業務連絡
      attendanceData.health,            // H列: 本日の体調
      attendanceData.sleep,             // I列: 睡眠状況
      attendanceData.checkinComment,    // J列: 出勤時利用者コメント
      attendanceData.fatigue,           // K列: 疲労感
      attendanceData.stress,            // L列: 心理的負荷
      attendanceData.checkoutComment,   // M列: 退勤時利用者コメント
      '',                               // N列: 予備
      '',                               // O列: 予備
      attendanceData.checkinTime,       // P列: 勤務開始時刻
      attendanceData.checkoutTime,      // Q列: 勤務終了時刻
      attendanceData.lunchBreak,        // R列: 昼休憩
      attendanceData.shortBreak,        // S列: 15分休憩
      attendanceData.otherBreak,        // T列: 他休憩時間
      attendanceData.workMinutes,       // U列: 実労時間
      attendanceData.mealService,       // V列: 食事提供
      attendanceData.absenceSupport,    // W列: 欠席対応
      attendanceData.visitSupport,      // X列: 訪問支援
      attendanceData.transport          // Y列: 送迎
    ];

    // Z-AL列のデータ（手動入力）
    const supportData = [
      data.userStatus || '',            // Z列: 本人の状況
      data.workLocation || '',          // AA列: 勤務地
      data.recorder || '',              // AB列: 記録者
      '',                               // AC列: 予備
      data.homeSupportEval || '',       // AD列: 在宅支援評価対象
      data.externalEval || '',          // AE列: 施設外評価対象
      data.workGoal || '',              // AF列: 作業目標
      data.workEval || '',              // AG列: 勤務評価
      data.employmentEval || '',        // AH列: 就労評価
      data.workMotivation || '',        // AI列: 就労意欲
      data.communication || '',         // AJ列: 通信連絡対応
      data.evaluation || '',            // AK列: 評価
      data.userFeedback || ''           // AL列: 利用者の感想
    ];

    const allData = baseData.concat(supportData);

    if (existingRow) {
      // 更新
      supportSheet.getRange(existingRow, 1, 1, 38).setValues([allData]);
      return createSuccessResponse({
        message: '支援記録を更新しました',
        rowId: existingRow
      });
    } else {
      // 新規作成 - 最終行の次に追加
      const newRow = supportSheet.getLastRow() + 1;
      supportSheet.getRange(newRow, 1, 1, 38).setValues([allData]);
      return createSuccessResponse({
        message: '支援記録を作成しました',
        rowId: newRow
      });
    }
  } catch (error) {
    return createErrorResponse('支援記録保存エラー: ' + error.message);
  }
}

/**
 * 支援記録の行を検索
 */
function findSupportRecordRow(sheet, date, userName) {
  const lastRow = sheet.getLastRow();
  if (lastRow < 2) return null;

  const dataRange = sheet.getRange(2, SUPPORT_COLS.DATE, lastRow - 1, 2).getValues();

  for (let i = dataRange.length - 1; i >= 0; i--) {
    const rowDate = formatDate(dataRange[i][0]);
    const rowUserName = dataRange[i][1];
    if (rowDate === date && rowUserName === userName) {
      return i + 2;
    }
  }
  return null;
}

/**
 * 勤怠データを支援記録用に取得
 */
function getAttendanceDataForSupport(sheet, date, userName) {
  const lastRow = sheet.getLastRow();
  if (lastRow < 2) return null;

  const allData = sheet.getRange(2, 1, lastRow - 1, 28).getValues();

  for (let i = allData.length - 1; i >= 0; i--) {
    const rowData = allData[i];
    const rowDate = formatDate(rowData[SUPPORT_COLS.DATE - 1]);
    const rowUserName = rowData[SUPPORT_COLS.USER_NAME - 1];

    if (rowDate === date && rowUserName === userName) {
      return {
        date: rowData[SUPPORT_COLS.DATE - 1],
        userName: rowData[SUPPORT_COLS.USER_NAME - 1],
        scheduled: rowData[SUPPORT_COLS.SCHEDULED - 1],
        attendance: rowData[SUPPORT_COLS.ATTENDANCE - 1],
        morningTask: rowData[SUPPORT_COLS.MORNING_TASK - 1],
        afternoonTask: rowData[SUPPORT_COLS.AFTERNOON_TASK - 1],
        workplace: rowData[SUPPORT_COLS.WORKPLACE - 1],
        health: rowData[SUPPORT_COLS.HEALTH - 1],
        sleep: rowData[SUPPORT_COLS.SLEEP - 1],
        checkinComment: rowData[SUPPORT_COLS.CHECKIN_COMMENT - 1],
        fatigue: rowData[SUPPORT_COLS.FATIGUE - 1],
        stress: rowData[SUPPORT_COLS.STRESS - 1],
        checkoutComment: rowData[SUPPORT_COLS.CHECKOUT_COMMENT - 1],
        checkinTime: rowData[SUPPORT_COLS.CHECKIN_TIME - 1],
        checkoutTime: rowData[SUPPORT_COLS.CHECKOUT_TIME - 1],
        lunchBreak: rowData[SUPPORT_COLS.LUNCH_BREAK - 1],
        shortBreak: rowData[SUPPORT_COLS.SHORT_BREAK - 1],
        otherBreak: rowData[SUPPORT_COLS.OTHER_BREAK - 1],
        workMinutes: rowData[SUPPORT_COLS.WORK_MINUTES - 1],
        mealService: rowData[SUPPORT_COLS.MEAL_SERVICE - 1],
        absenceSupport: rowData[SUPPORT_COLS.ABSENCE_SUPPORT - 1],
        visitSupport: rowData[SUPPORT_COLS.VISIT_SUPPORT - 1],
        transport: rowData[SUPPORT_COLS.TRANSPORT - 1]
      };
    }
  }
  return null;
}

/**
 * 配列データから支援記録オブジェクトを作成
 */
function parseSupportRecordFromArray(rowData, rowId) {
  return {
    rowId: rowId,
    // A-Y列: 勤怠データ
    date: formatDate(rowData[SUPPORT_COLS.DATE - 1]),
    userName: rowData[SUPPORT_COLS.USER_NAME - 1],
    scheduled: rowData[SUPPORT_COLS.SCHEDULED - 1],
    attendance: rowData[SUPPORT_COLS.ATTENDANCE - 1],
    morningTask: rowData[SUPPORT_COLS.MORNING_TASK - 1],
    afternoonTask: rowData[SUPPORT_COLS.AFTERNOON_TASK - 1],
    workplace: rowData[SUPPORT_COLS.WORKPLACE - 1],
    health: rowData[SUPPORT_COLS.HEALTH - 1],
    sleep: rowData[SUPPORT_COLS.SLEEP - 1],
    checkinComment: rowData[SUPPORT_COLS.CHECKIN_COMMENT - 1],
    fatigue: rowData[SUPPORT_COLS.FATIGUE - 1],
    stress: rowData[SUPPORT_COLS.STRESS - 1],
    checkoutComment: rowData[SUPPORT_COLS.CHECKOUT_COMMENT - 1],
    checkinTime: rowData[SUPPORT_COLS.CHECKIN_TIME - 1],
    checkoutTime: rowData[SUPPORT_COLS.CHECKOUT_TIME - 1],
    lunchBreak: rowData[SUPPORT_COLS.LUNCH_BREAK - 1],
    shortBreak: rowData[SUPPORT_COLS.SHORT_BREAK - 1],
    otherBreak: rowData[SUPPORT_COLS.OTHER_BREAK - 1],
    workMinutes: rowData[SUPPORT_COLS.WORK_MINUTES - 1],
    mealService: rowData[SUPPORT_COLS.MEAL_SERVICE - 1],
    absenceSupport: rowData[SUPPORT_COLS.ABSENCE_SUPPORT - 1],
    visitSupport: rowData[SUPPORT_COLS.VISIT_SUPPORT - 1],
    transport: rowData[SUPPORT_COLS.TRANSPORT - 1],
    // Z-AL列: 支援記録データ
    userStatus: rowData[SUPPORT_COLS.USER_STATUS - 1],
    workLocation: rowData[SUPPORT_COLS.WORK_LOCATION - 1],
    recorder: rowData[SUPPORT_COLS.RECORDER - 1],
    homeSupportEval: rowData[SUPPORT_COLS.HOME_SUPPORT_EVAL - 1],
    externalEval: rowData[SUPPORT_COLS.EXTERNAL_EVAL - 1],
    workGoal: rowData[SUPPORT_COLS.WORK_GOAL - 1],
    workEval: rowData[SUPPORT_COLS.WORK_EVAL - 1],
    employmentEval: rowData[SUPPORT_COLS.EMPLOYMENT_EVAL - 1],
    workMotivation: rowData[SUPPORT_COLS.WORK_MOTIVATION - 1],
    communication: rowData[SUPPORT_COLS.COMMUNICATION - 1],
    evaluation: rowData[SUPPORT_COLS.EVALUATION - 1],
    userFeedback: rowData[SUPPORT_COLS.USER_FEEDBACK - 1]
  };
}

// ========================================
// ユーティリティ関数
// ========================================

/**
 * 時刻をシリアル値に変換（文字列/Date型 → 0〜1の小数）
 */
function timeStringToSerial(timeStr) {
  if (!timeStr || timeStr === '') return 0;

  // 既に数値（シリアル値）の場合はそのまま返す
  if (typeof timeStr === 'number') return timeStr;

  // Date型オブジェクトの場合
  if (timeStr instanceof Date) {
    const hours = timeStr.getHours();
    const minutes = timeStr.getMinutes();
    const seconds = timeStr.getSeconds();
    // シリアル値に変換（1日=1.0なので、時間を24で割る）
    return (hours + minutes / 60 + seconds / 3600) / 24;
  }

  // HH:mm形式の文字列を分解
  const match = String(timeStr).match(/^(\d{1,2}):(\d{2})$/);
  if (!match) return 0;

  const hours = parseInt(match[1], 10);
  const minutes = parseInt(match[2], 10);

  // シリアル値に変換（1日=1.0なので、時間を24で割る）
  return (hours + minutes / 60) / 24;
}

/**
 * 実労時間を計算（数式の代わり）
 * 計算式: (終了時刻 - 開始時刻 - 昼休憩 - 15分休憩 - 他休憩) * 24
 */
function calculateWorkMinutes(checkinTime, checkoutTime, lunchBreak, shortBreak, otherBreak) {
  // いずれかが空の場合は計算しない
  if (!checkoutTime || checkoutTime === '') {
    return '';
  }

  try {
    // 時刻をシリアル値に変換
    const checkout = timeStringToSerial(checkoutTime);
    const checkin = timeStringToSerial(checkinTime);

    // 休憩時間も時刻形式（HH:mm）またはDate型の可能性があるため、シリアル値に変換
    const lunch = timeStringToSerial(lunchBreak);
    const short = timeStringToSerial(shortBreak);
    const other = timeStringToSerial(otherBreak);

    // 計算: (終了 - 開始 - 昼 - 15分 - 他) * 24 = 実労時間（時間）
    const result = (checkout - checkin - lunch - short - other) * 24;

    // 小数第2位で四捨五入（例: 7.5時間、8.25時間）
    // 0以下の場合は0を返す
    return result > 0 ? Math.round(result * 100) / 100 : 0;
  } catch (error) {
    Logger.log('calculateWorkMinutes エラー: ' + error.message);
    return 0;
  }
}

/**
 * 実際にデータがある最下行を見つける（空白行・数式のみの行を除外）
 * 【最適化】最後の500行だけを検索し、末尾から逆順に探索
 *
 * @param {Sheet} sheet - 対象シート
 * @param {number} userNameColumn - 検索対象列（通常はB列=2）
 * @return {number} 実際にデータがある最下行番号
 */
function findActualLastRow(sheet, userNameColumn) {
  const lastRow = sheet.getLastRow();
  if (lastRow < 2) return 1;

  // 【最適化】最後の500行だけを取得（または全体が500行未満ならすべて）
  const SEARCH_RANGE = 500;
  const searchRange = Math.min(SEARCH_RANGE, lastRow - 1);
  const startRow = Math.max(2, lastRow - searchRange + 1);

  // 検索範囲のデータを取得
  const data = sheet.getRange(startRow, userNameColumn, searchRange, 1).getValues();

  // 末尾から逆順に探索して、5行連続空白が続いたらそこを終端とみなす
  let consecutiveEmpty = 0;
  let actualLast = 1;

  for (let i = data.length - 1; i >= 0; i--) {
    const value = data[i][0];
    if (value && value !== '') {
      // データ発見 → これが最終行
      actualLast = startRow + i;
      break;
    } else {
      // 空白行
      consecutiveEmpty++;
      if (consecutiveEmpty >= 5) {
        // 5行連続空白 → 直後の行を最終行とする
        actualLast = startRow + i + 5;
        break;
      }
    }
  }

  return Math.max(1, actualLast);
}

