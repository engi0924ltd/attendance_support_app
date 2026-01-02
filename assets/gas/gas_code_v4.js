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

// デフォルト年度（後方互換性のため）
const DEFAULT_FISCAL_YEAR = 2025;

// 固定シート名
const FIXED_SHEET_NAMES = {
  MASTER: 'マスタ設定'
};

// 年度付きシート名を動的に生成
function getSheetNames(fiscalYear) {
  const year = fiscalYear || DEFAULT_FISCAL_YEAR;
  return {
    MASTER: 'マスタ設定',
    ATTENDANCE: `支援記録_${year}`,
    SUPPORT: `支援記録_${year}`,
    ROSTER: `名簿_${year}`
  };
}

// 後方互換性のためのデフォルトSHEET_NAMES
const SHEET_NAMES = getSheetNames(DEFAULT_FISCAL_YEAR);

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
  STAFF_DATA_END_ROW: 40,   // 40行まで対応（V8:V40、最大33人）

  STAFF_COLS: {
    NAME: 22,       // V列: 職員名
    ROLE: 23,       // W列: 権限
    EMAIL: 24,      // X列: メールアドレス
    PASSWORD: 25,   // Y列: パスワード
    JOB_TYPE: 26,   // Z列: 職種
    QUALIFICATION: 27,  // AA列: 保有福祉資格
    PLACEMENT: 28,  // AB列: 職員配置
    EMPLOYMENT_TYPE: 29, // AC列: 雇用形態
    RETIREMENT_DATE: 30  // AD列: 退職日
  },

  // 支援記録用プルダウン選択肢（AC列、V列、AD〜AH列、8〜25行目）
  SUPPORT_DROPDOWN_START_ROW: 8,
  SUPPORT_DROPDOWN_END_ROW: 25,
  // 職員関連プルダウン選択肢（T〜W列、44〜55行目）
  WORK_LOCATION_DROPDOWN_START_ROW: 44,   // 勤務地: W44〜W55
  WORK_LOCATION_DROPDOWN_END_ROW: 55,
  WORK_LOCATION_DROPDOWN_COL: 23,         // W列: 勤務地
  QUALIFICATION_DROPDOWN_START_ROW: 44,   // 資格選択肢: T44〜T55
  QUALIFICATION_DROPDOWN_END_ROW: 55,
  QUALIFICATION_DROPDOWN_COL: 20,         // T列: 資格選択肢
  PLACEMENT_DROPDOWN_START_ROW: 44,       // 職員配置選択肢: U44〜U55
  PLACEMENT_DROPDOWN_END_ROW: 55,
  PLACEMENT_DROPDOWN_COL: 21,             // U列: 職員配置選択肢
  JOB_TYPE_DROPDOWN_START_ROW: 44,        // 職種選択肢: V44〜V55
  JOB_TYPE_DROPDOWN_END_ROW: 55,
  JOB_TYPE_DROPDOWN_COL: 22,              // V列: 職種
  // 雇用形態プルダウン（X列、44〜55行目）
  EMPLOYMENT_TYPE_DROPDOWN_START_ROW: 44, // 雇用形態: X44〜X55
  EMPLOYMENT_TYPE_DROPDOWN_END_ROW: 55,
  EMPLOYMENT_TYPE_DROPDOWN_COL: 24,       // X列: 雇用形態
  // 勤怠評価プルダウン（AE列、30〜40行目）
  WORK_EVAL_DROPDOWN_START_ROW: 30,       // 勤怠評価: AE30〜AE40
  WORK_EVAL_DROPDOWN_END_ROW: 40,
  WORK_EVAL_DROPDOWN_COL: 31,             // AE列: 勤怠評価
  SUPPORT_DROPDOWN_COLS: {
    WORK_LOCATION: 23,    // W列: 勤務地（44〜55行目）
    QUALIFICATION: 20,    // T列: 資格選択肢（44〜55行目）
    PLACEMENT: 21,        // U列: 職員配置選択肢（44〜55行目）
    JOB_TYPE: 22,         // V列: 職種（44〜55行目）
    RECORDER: 22,         // V列: 記録者（職員名と同じ列）※旧設定維持
    WORK_EVAL: 31,        // AE列: 勤怠評価（30〜40行目）
    EMPLOYMENT_EVAL: 32,  // AF列: 就労評価（品質・生産性）
    WORK_MOTIVATION: 33,  // AG列: 就労意欲
    COMMUNICATION: 34,    // AH列: 通信連絡対応度
    EVALUATION: 35        // AI列: 評価
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

  // 期間計算（AI〜AJ列）
  USE_PERIOD: 35,       // AI列: 本日までの利用期間（自動計算）
  INITIAL_ADDITION: 36, // AJ列: 初期加算有効期間（30日）

  // 受給者証情報（AK列）
  USER_BURDEN_LIMIT: 37, // AK列: 利用者負担上限月額

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
    } else if (action === 'master/all-users') {
      return handleGetAllUsers();
    } else if (action === 'master/dropdowns') {
      return handleGetDropdowns();
    } else if (action === 'master/evaluation-alerts') {
      return handleGetEvaluationAlerts();
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
    } else if (action.startsWith('attendance/history/')) {
      // 利用者の過去記録一覧を取得
      const userName = decodeURIComponent(action.split('/')[2]);
      return handleGetUserHistory(userName);
    } else if (action.startsWith('attendance/health-batch/')) {
      // 複数利用者の健康履歴をバッチ取得
      const userNames = decodeURIComponent(action.split('/')[2]).split(',');
      return handleGetHealthBatch(userNames);
    } else if (action === 'chatwork/users') {
      return handleGetChatworkUsers();
    } else if (action === 'analytics/facility-stats') {
      return handleGetFacilityStats();
    } else if (action.startsWith('analytics/facility-stats/')) {
      // 月別統計: analytics/facility-stats/2025-01
      const month = action.split('/')[2];
      return handleGetFacilityStats(month);
    } else if (action === 'analytics/weekly-schedule') {
      return handleGetWeeklySchedule();
    } else if (action.startsWith('analytics/user-stats/')) {
      const userName = decodeURIComponent(action.split('/')[2]);
      return handleGetUserStats(userName);
    } else if (action === 'analytics/departed-users') {
      return handleGetDepartedUsers();
    } else if (action.startsWith('analytics/departed-users/')) {
      // 月別退所者: analytics/departed-users/2025-01
      const month = action.split('/')[2];
      return handleGetDepartedUsers(month);
    } else if (action === 'analytics/yearly-stats') {
      // 当年度統計
      return handleGetYearlyStats();
    } else if (action.startsWith('analytics/yearly-stats/')) {
      // 指定年度統計: analytics/yearly-stats/2024 (2024年度 = 2024/4 - 2025/3)
      const fiscalYear = parseInt(action.split('/')[2], 10);
      return handleGetYearlyStats(fiscalYear);
    } else if (action === 'analytics/batch') {
      // バッチ取得（施設統計・退所者・曜日別予定を一括取得）
      return handleGetAnalyticsBatch();
    } else if (action.startsWith('analytics/batch/')) {
      // 月別バッチ取得: analytics/batch/2025-01
      const month = action.split('/')[2];
      return handleGetAnalyticsBatch(month);
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
    } else if (action === 'chatwork/broadcast') {
      return handleChatworkBroadcast(data);
    } else if (action === 'chatwork/set-api-key') {
      return handleSetChatworkApiKey(data);
    } else if (action === 'fiscal-year/create-next') {
      return handleCreateNextFiscalYear(data);
    } else if (action === 'fiscal-year/get-available') {
      return handleGetAvailableFiscalYears();
    } else if (action === 'billing/get-dropdowns') {
      return handleGetBillingDropdowns();
    } else if (action === 'billing/save-settings') {
      return handleSaveBillingSettings(data);
    } else if (action === 'billing/get-settings') {
      return handleGetBillingSettings();
    } else if (action === 'billing/get-monthly-users') {
      return handleGetMonthlyUsers(data);
    } else if (action === 'municipality/get') {
      return handleGetMunicipalities();
    } else if (action === 'municipality/add') {
      return handleAddMunicipality(data);
    } else if (action === 'municipality/delete') {
      return handleDeleteMunicipality(data);
    } else if (action === 'billing/execute') {
      return handleExecuteBilling(data);
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

/**
 * 全利用者一覧を取得（退所済み含む）
 * 過去の実績記録画面用
 */
function handleGetAllUsers() {
  const sheet = getSheet(SHEET_NAMES.MASTER);
  const users = [];

  // 【最適化】利用者データを一括取得（8行目から最大500行まで）
  const startRow = MASTER_CONFIG.USER_DATA_START_ROW;
  const maxRows = 500;
  const numCols = 3; // NAME, FURIGANA, STATUS

  const allData = sheet.getRange(startRow, MASTER_CONFIG.USER_COLS.NAME, maxRows, numCols).getValues();

  for (let i = 0; i < allData.length; i++) {
    const name = allData[i][0];
    const furigana = allData[i][1];
    const status = allData[i][2];

    if (!name || name === '') {
      break;
    }

    // 全利用者を返す（ステータス問わず）
    users.push({
      name: name,
      furigana: furigana || '',
      status: status || ''
    });
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
    // 職員関連プルダウン（T〜X列、44〜55行目）
    workLocations: getColumnOptions(sheet, MASTER_CONFIG.WORK_LOCATION_DROPDOWN_COL, MASTER_CONFIG.WORK_LOCATION_DROPDOWN_START_ROW, MASTER_CONFIG.WORK_LOCATION_DROPDOWN_END_ROW),  // W列: 勤務地（44〜55行目）
    qualifications: getColumnOptions(sheet, MASTER_CONFIG.QUALIFICATION_DROPDOWN_COL, MASTER_CONFIG.QUALIFICATION_DROPDOWN_START_ROW, MASTER_CONFIG.QUALIFICATION_DROPDOWN_END_ROW),  // T列: 資格選択肢（44〜55行目）
    placements: getColumnOptions(sheet, MASTER_CONFIG.PLACEMENT_DROPDOWN_COL, MASTER_CONFIG.PLACEMENT_DROPDOWN_START_ROW, MASTER_CONFIG.PLACEMENT_DROPDOWN_END_ROW),  // U列: 職員配置選択肢（44〜55行目）
    jobTypes: getColumnOptions(sheet, MASTER_CONFIG.JOB_TYPE_DROPDOWN_COL, MASTER_CONFIG.JOB_TYPE_DROPDOWN_START_ROW, MASTER_CONFIG.JOB_TYPE_DROPDOWN_END_ROW),  // V列: 職種選択肢（44〜55行目）
    employmentTypes: getColumnOptions(sheet, MASTER_CONFIG.EMPLOYMENT_TYPE_DROPDOWN_COL, MASTER_CONFIG.EMPLOYMENT_TYPE_DROPDOWN_START_ROW, MASTER_CONFIG.EMPLOYMENT_TYPE_DROPDOWN_END_ROW),  // X列: 雇用形態（44〜55行目）

    // 曜日別出欠予定用プルダウン（K列、44〜55行目）
    scheduledWeekly: getColumnOptions(sheet, MASTER_CONFIG.SCHEDULED_WEEKLY_DROPDOWN_COL, MASTER_CONFIG.SCHEDULED_WEEKLY_DROPDOWN_START_ROW, MASTER_CONFIG.SCHEDULED_WEEKLY_DROPDOWN_END_ROW), // K列: 曜日別出欠予定

    // 支援記録用プルダウン
    recorders: getColumnOptions(sheet, MASTER_CONFIG.SUPPORT_DROPDOWN_COLS.RECORDER, MASTER_CONFIG.SUPPORT_DROPDOWN_START_ROW, MASTER_CONFIG.SUPPORT_DROPDOWN_END_ROW),  // V列: 記録者（8〜25行目）

    // 評価項目プルダウン（AE〜AI列）
    workEvaluations: getColumnOptions(sheet, MASTER_CONFIG.WORK_EVAL_DROPDOWN_COL, MASTER_CONFIG.WORK_EVAL_DROPDOWN_START_ROW, MASTER_CONFIG.WORK_EVAL_DROPDOWN_END_ROW),           // AE列: 勤怠評価（30〜40行目）
    employmentEvaluations: getColumnOptions(sheet, MASTER_CONFIG.SUPPORT_DROPDOWN_COLS.EMPLOYMENT_EVAL, MASTER_CONFIG.SUPPORT_DROPDOWN_START_ROW, MASTER_CONFIG.SUPPORT_DROPDOWN_END_ROW),   // AF列: 就労評価（8〜25行目）
    workMotivations: getColumnOptions(sheet, MASTER_CONFIG.SUPPORT_DROPDOWN_COLS.WORK_MOTIVATION, MASTER_CONFIG.SUPPORT_DROPDOWN_START_ROW, MASTER_CONFIG.SUPPORT_DROPDOWN_END_ROW),     // AG列: 就労意欲（8〜25行目）
    communications: getColumnOptions(sheet, MASTER_CONFIG.SUPPORT_DROPDOWN_COLS.COMMUNICATION, MASTER_CONFIG.SUPPORT_DROPDOWN_START_ROW, MASTER_CONFIG.SUPPORT_DROPDOWN_END_ROW),         // AH列: 通信連絡対応度（8〜25行目）
    evaluations: getColumnOptions(sheet, MASTER_CONFIG.SUPPORT_DROPDOWN_COLS.EVALUATION, MASTER_CONFIG.SUPPORT_DROPDOWN_START_ROW, MASTER_CONFIG.SUPPORT_DROPDOWN_END_ROW),               // AI列: 評価（8〜25行目）

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
 * 評価アラート情報を取得
 * 支援記録で「在宅支援評価対象」をONにした日から1週間経過でアラート
 * 支援記録で「施設外評価対象」をONにした日から2週間経過でアラート
 * ※キャッシュ機能により、5分間は同じデータを再利用
 */
function handleGetEvaluationAlerts() {
  // キャッシュをチェック
  const cacheKey = 'evaluation_alerts';
  const cachedData = getCacheData(cacheKey);
  if (cachedData) {
    return createSuccessResponse({ alerts: cachedData, cached: true });
  }

  const supportSheet = getSheet(SHEET_NAMES.SUPPORT);
  const masterSheet = getSheet(SHEET_NAMES.MASTER);

  const alerts = [];
  const today = new Date();
  const ONE_WEEK_MS = 7 * 24 * 60 * 60 * 1000;
  const TWO_WEEKS_MS = 14 * 24 * 60 * 60 * 1000;

  // === Step 1: マスタシートから利用者の出勤予定を取得 ===
  const masterLastRow = masterSheet.getLastRow();
  const userScheduleMap = {}; // { userName: { needsHomeEval: boolean, needsExternalEval: boolean } }

  if (masterLastRow >= MASTER_CONFIG.USER_DATA_START_ROW) {
    const startRow = MASTER_CONFIG.USER_DATA_START_ROW;
    const numRows = masterLastRow - startRow + 1;
    // A列(名前), C列(状態), D-J列(曜日別予定)を取得
    const masterData = masterSheet.getRange(startRow, 1, numRows, 10).getValues();

    for (let i = 0; i < masterData.length; i++) {
      const name = masterData[i][MASTER_CONFIG.USER_COLS.NAME - 1];
      const status = masterData[i][MASTER_CONFIG.USER_COLS.STATUS - 1];

      // 空白行または退所済みはスキップ
      if (!name || name === '' || status !== '契約中') {
        continue;
      }

      // 曜日別予定をチェック（D-J列、インデックス3-9）
      let needsHomeEval = false;
      let needsExternalEval = false;

      for (let col = 3; col <= 9; col++) {
        const schedule = masterData[i][col];
        if (schedule) {
          const scheduleStr = String(schedule);
          // 在宅チェック
          if (scheduleStr.includes('在宅')) {
            needsHomeEval = true;
          }
          // 施設外チェック
          if (scheduleStr.includes('施設外')) {
            needsExternalEval = true;
          }
        }
      }

      if (needsHomeEval || needsExternalEval) {
        userScheduleMap[name] = {
          needsHomeEval: needsHomeEval,
          needsExternalEval: needsExternalEval
        };
      }
    }
  }

  // === Step 2: 支援記録から評価履歴を取得 ===
  const actualLastRow = findActualLastRow(supportSheet, SUPPORT_COLS.USER_NAME);

  // 各利用者の最終評価日を集計
  const userEvalMap = {};

  if (actualLastRow >= 2) {
    const MAX_SEARCH_ROWS = 500;
    const searchRows = Math.min(actualLastRow - 1, MAX_SEARCH_ROWS);
    const startRow = Math.max(2, actualLastRow - searchRows + 1);

    const dateCol = supportSheet.getRange(startRow, SUPPORT_COLS.DATE, searchRows, 1).getValues();
    const nameCol = supportSheet.getRange(startRow, SUPPORT_COLS.USER_NAME, searchRows, 1).getValues();
    const homeCol = supportSheet.getRange(startRow, SUPPORT_COLS.HOME_SUPPORT_EVAL, searchRows, 1).getValues();
    const externalCol = supportSheet.getRange(startRow, SUPPORT_COLS.EXTERNAL_EVAL, searchRows, 1).getValues();

    for (let i = 0; i < searchRows; i++) {
      if (!dateCol[i][0] || !nameCol[i][0]) continue;

      const userName = nameCol[i][0];

      if (!userEvalMap[userName]) {
        userEvalMap[userName] = {
          lastHomeDate: null,
          lastExternalDate: null,
          hasHomeEval: false,
          hasExternalEval: false
        };
      }

      // 在宅支援評価対象が○の場合 (Unicode: ○ = U+25CB)
      if (homeCol[i][0] === '\u25CB') {
        userEvalMap[userName].hasHomeEval = true;
        const evalDate = new Date(dateCol[i][0]);
        if (!userEvalMap[userName].lastHomeDate || evalDate > userEvalMap[userName].lastHomeDate) {
          userEvalMap[userName].lastHomeDate = evalDate;
        }
      }

      // 施設外評価対象が○の場合 (Unicode: ○ = U+25CB)
      if (externalCol[i][0] === '\u25CB') {
        userEvalMap[userName].hasExternalEval = true;
        const evalDate = new Date(dateCol[i][0]);
        if (!userEvalMap[userName].lastExternalDate || evalDate > userEvalMap[userName].lastExternalDate) {
          userEvalMap[userName].lastExternalDate = evalDate;
        }
      }
    }
  }

  // === Step 3: アラート判定 ===
  // 既存の評価履歴があるユーザーのアラート
  for (const userName in userEvalMap) {
    const evalInfo = userEvalMap[userName];

    // 在宅支援評価のアラート判定
    if (evalInfo.hasHomeEval && evalInfo.lastHomeDate) {
      const elapsed = today - evalInfo.lastHomeDate;
      if (elapsed >= ONE_WEEK_MS) {
        const daysSinceLastEval = Math.floor(elapsed / (24 * 60 * 60 * 1000));
        alerts.push({
          userName: userName,
          alertType: 'home',
          message: `在宅支援評価が${daysSinceLastEval}日間未入力です`,
          daysSinceLastEval: daysSinceLastEval,
          lastEvalDate: formatDate(evalInfo.lastHomeDate)
        });
        // continueを削除：施設外アラートも同時にチェックする
      }
    }

    // 施設外評価のアラート判定
    if (evalInfo.hasExternalEval && evalInfo.lastExternalDate) {
      const elapsed = today - evalInfo.lastExternalDate;
      if (elapsed >= TWO_WEEKS_MS) {
        const daysSinceLastEval = Math.floor(elapsed / (24 * 60 * 60 * 1000));
        alerts.push({
          userName: userName,
          alertType: 'external',
          message: `施設外評価が${daysSinceLastEval}日間未入力です`,
          daysSinceLastEval: daysSinceLastEval,
          lastEvalDate: formatDate(evalInfo.lastExternalDate)
        });
      }
    }
  }

  // マスタに予定があるが一度も評価していないユーザーのアラート
  for (const userName in userScheduleMap) {
    const schedule = userScheduleMap[userName];
    const evalInfo = userEvalMap[userName];

    // 在宅予定があるが一度も評価していない
    if (schedule.needsHomeEval && (!evalInfo || !evalInfo.hasHomeEval)) {
      // 既にこのユーザーの在宅アラートがなければ追加
      const hasHomeAlert = alerts.some(a => a.userName === userName && a.alertType === 'home');
      if (!hasHomeAlert) {
        alerts.push({
          userName: userName,
          alertType: 'home',
          message: '在宅支援評価が未実施です（初回評価が必要）',
          daysSinceLastEval: 0,
          lastEvalDate: null
        });
      }
    }

    // 施設外予定があるが一度も評価していない
    if (schedule.needsExternalEval && (!evalInfo || !evalInfo.hasExternalEval)) {
      // 既にこのユーザーの施設外アラートがなければ追加
      const hasExternalAlert = alerts.some(a => a.userName === userName && a.alertType === 'external');
      if (!hasExternalAlert) {
        alerts.push({
          userName: userName,
          alertType: 'external',
          message: '施設外評価が未実施です（初回評価が必要）',
          daysSinceLastEval: 0,
          lastEvalDate: null
        });
      }
    }
  }

  // キャッシュに保存（5分間有効）
  setCacheData(cacheKey, alerts, 300);

  return createSuccessResponse({ alerts: alerts, cached: false });
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
  const cols = MASTER_CONFIG.STAFF_COLS;

  // 職員データを一括取得（V列〜AD列: NAME〜RETIREMENT_DATE）
  const numRows = MASTER_CONFIG.STAFF_DATA_END_ROW - MASTER_CONFIG.STAFF_DATA_START_ROW + 1;
  const numCols = cols.RETIREMENT_DATE - cols.NAME + 1; // V列からAD列まで
  const allData = sheet.getRange(
    MASTER_CONFIG.STAFF_DATA_START_ROW,
    cols.NAME,
    numRows,
    numCols
  ).getValues();

  // データを検索
  for (let i = 0; i < allData.length; i++) {
    const staffName = allData[i][0];     // V列: NAME
    const staffRole = allData[i][1];     // W列: ROLE
    const staffEmail = allData[i][2];    // X列: EMAIL
    const staffPassword = allData[i][3]; // Y列: PASSWORD
    const retirementDate = allData[i][cols.RETIREMENT_DATE - cols.NAME]; // AD列: 退職日

    // メールアドレスチェック（前後の空白を削除して比較）
    if (staffEmail && String(staffEmail).trim() === String(email).trim()) {
      // 退職日が入力されている場合はログイン拒否
      if (retirementDate && retirementDate !== '') {
        return createErrorResponse('このアカウントは無効です');
      }

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
    const startRow = MASTER_CONFIG.STAFF_DATA_START_ROW;
    const endRow = MASTER_CONFIG.STAFF_DATA_END_ROW;
    const numRows = endRow - startRow + 1;

    // 必要な列を一括取得（V:名前, W:権限, X:メール, Z:職種, AA:資格, AB:配置, AC:雇用形態, AD:退職日）
    const nameCol = MASTER_CONFIG.STAFF_COLS.NAME;      // V列 = 22
    const roleCol = MASTER_CONFIG.STAFF_COLS.ROLE;      // W列 = 23
    const emailCol = MASTER_CONFIG.STAFF_COLS.EMAIL;    // X列 = 24
    const jobTypeCol = MASTER_CONFIG.STAFF_COLS.JOB_TYPE; // Z列 = 26
    const qualificationCol = MASTER_CONFIG.STAFF_COLS.QUALIFICATION; // AA列 = 27
    const placementCol = MASTER_CONFIG.STAFF_COLS.PLACEMENT; // AB列 = 28
    const employmentTypeCol = MASTER_CONFIG.STAFF_COLS.EMPLOYMENT_TYPE; // AC列 = 29
    const retirementDateCol = MASTER_CONFIG.STAFF_COLS.RETIREMENT_DATE; // AD列 = 30

    // V列からAD列まで一括取得（22列目から30列目 = 9列分）
    const allData = sheet.getRange(startRow, nameCol, numRows, retirementDateCol - nameCol + 1).getValues();

    const staffList = [];
    for (let i = 0; i < allData.length; i++) {
      const row = allData[i];
      const name = row[0];                        // V列（配列インデックス0）
      const role = row[roleCol - nameCol];        // W列
      const email = row[emailCol - nameCol];      // X列
      const jobType = row[jobTypeCol - nameCol];  // Z列
      const qualification = row[qualificationCol - nameCol];  // AA列
      const placement = row[placementCol - nameCol];  // AB列
      const employmentType = row[employmentTypeCol - nameCol];  // AC列
      const retirementDate = row[retirementDateCol - nameCol];  // AD列

      // 名前とメールアドレスが両方入力されている行のみ取得
      if (name && email) {
        staffList.push({
          name: name,
          email: email,
          role: role || '従業員',
          jobType: jobType || null,
          qualification: qualification || null,
          placement: placement || null,
          employmentType: employmentType || null,
          retirementDate: retirementDate ? formatDateYYYYMMDD(retirementDate) : null,
          rowNumber: startRow + i
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
 * 一括取得・一括書き込みで高速化
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
    const cols = MASTER_CONFIG.STAFF_COLS;
    const startRow = MASTER_CONFIG.STAFF_DATA_START_ROW;
    const endRow = MASTER_CONFIG.STAFF_DATA_END_ROW;
    const numRows = endRow - startRow + 1;

    // V列からZ列まで一括取得（名前、権限、メール、パスワード、職種）
    const allData = sheet.getRange(startRow, cols.NAME, numRows, cols.JOB_TYPE - cols.NAME + 1).getValues();

    // メールアドレスの重複チェックと空行探しを同時に実行
    let newRow = -1;
    const emailColIndex = cols.EMAIL - cols.NAME; // 配列内のメール列インデックス
    const nameColIndex = 0; // 名前は最初の列

    for (let i = 0; i < allData.length; i++) {
      const row = allData[i];
      const existingEmail = row[emailColIndex];
      const existingName = row[nameColIndex];

      // メール重複チェック
      if (existingEmail && existingEmail.toString().toLowerCase() === data.email.toLowerCase()) {
        return createErrorResponse('このメールアドレスは既に登録されています');
      }

      // 空行を探す（最初に見つかった空行を記録）
      if (newRow === -1 && (!existingName || existingName === '')) {
        newRow = startRow + i;
      }
    }

    // 空行が見つからなければ最後に追加
    if (newRow === -1) {
      newRow = startRow + allData.length;
    }

    // データを一括書き込み（V:名前, W:権限, X:メール, Y:パスワード, Z:職種, AA:資格, AB:配置, AC:雇用形態, AD:退職日）
    const writeData = [[
      data.name,
      data.role,
      data.email,
      data.password,
      data.jobType || '',
      data.qualification || '',
      data.placement || '',
      data.employmentType || '',
      data.retirementDate || ''
    ]];
    sheet.getRange(newRow, cols.NAME, 1, 9).setValues(writeData);

    return createSuccessResponse({
      message: '職員を登録しました',
      staff: {
        name: data.name,
        email: data.email,
        role: data.role,
        jobType: data.jobType || null,
        qualification: data.qualification || null,
        placement: data.placement || null,
        employmentType: data.employmentType || null,
        retirementDate: data.retirementDate || null,
        rowNumber: newRow
      }
    });

  } catch (error) {
    return createErrorResponse('職員登録エラー: ' + error.message);
  }
}

/**
 * 職員情報を更新
 * 一括取得・一括書き込みで高速化
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
    const cols = MASTER_CONFIG.STAFF_COLS;
    const startRow = MASTER_CONFIG.STAFF_DATA_START_ROW;
    const endRow = MASTER_CONFIG.STAFF_DATA_END_ROW;
    const numRows = endRow - startRow + 1;

    // メール列を一括取得して重複チェック
    const emailData = sheet.getRange(startRow, cols.EMAIL, numRows, 1).getValues();
    for (let i = 0; i < emailData.length; i++) {
      const currentRow = startRow + i;
      if (currentRow === data.rowNumber) continue; // 自分自身はスキップ

      const existingEmail = emailData[i][0];
      if (existingEmail && existingEmail.toString().toLowerCase() === data.email.toLowerCase()) {
        return createErrorResponse('このメールアドレスは既に登録されています');
      }
    }

    // 現在のパスワードを取得（パスワード未指定時に使用）
    let password = data.password;
    if (!password) {
      password = sheet.getRange(data.rowNumber, cols.PASSWORD).getValue();
    }

    // データを一括書き込み（V:名前, W:権限, X:メール, Y:パスワード, Z:職種, AA:資格, AB:配置, AC:雇用形態, AD:退職日）
    const writeData = [[
      data.name,
      data.role,
      data.email,
      password,
      data.jobType || '',
      data.qualification || '',
      data.placement || '',
      data.employmentType || '',
      data.retirementDate || ''
    ]];
    sheet.getRange(data.rowNumber, cols.NAME, 1, 9).setValues(writeData);

    return createSuccessResponse({
      message: '職員情報を更新しました',
      staff: {
        name: data.name,
        email: data.email,
        role: data.role,
        jobType: data.jobType || null,
        qualification: data.qualification || null,
        placement: data.placement || null,
        employmentType: data.employmentType || null,
        retirementDate: data.retirementDate || null,
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

    // V-AD列のデータを一括クリア（V:名前〜AD:退職日 = 9列分）
    const cols = MASTER_CONFIG.STAFF_COLS;
    sheet.getRange(data.rowNumber, cols.NAME, 1, 9).clearContent();

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

  // 期間計算（AI列・AJ列は自動計算列のため書き込まない）

  // 受給者証情報（AK列）
  if (data.userBurdenLimit !== undefined) rosterSheet.getRange(rowNumber, cols.USER_BURDEN_LIMIT).setValue(data.userBurdenLimit || '');

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
 * 名簿_2025シートに利用者データを一括書き込み（パフォーマンス最適化版）
 * 50+回のsetValue()を1回のsetValues()に統合
 */
function writeToRosterSheetBatch(rosterSheet, rowNumber, data) {
  const cols = ROSTER_COLS;
  const maxCol = cols.NOTES; // 60列目が最後

  // 既存データを取得（更新時に上書きしない列を保持）
  const existingData = rosterSheet.getRange(rowNumber, 1, 1, maxCol).getValues()[0];

  // 新しいデータ配列を作成（既存データをベースに更新）
  const rowData = [...existingData];

  // ヘルパー関数: undefinedでなければ値を設定（空文字も許可）
  const setIfDefined = (colIndex, value) => {
    if (value !== undefined) {
      rowData[colIndex - 1] = value === null ? '' : value;
    }
  };

  // 基本情報
  setIfDefined(cols.NAME, data.name);
  setIfDefined(cols.NAME_KANA, data.furigana);
  setIfDefined(cols.STATUS, data.status);

  // 連絡先情報
  setIfDefined(cols.MOBILE_PHONE, data.mobilePhone);
  setIfDefined(cols.CHATWORK_ID, data.chatworkId);
  setIfDefined(cols.MAIL, data.mail);
  setIfDefined(cols.EMERGENCY_CONTACT1, data.emergencyContact1);
  setIfDefined(cols.EMERGENCY_PHONE1, data.emergencyPhone1);
  setIfDefined(cols.EMERGENCY_CONTACT2, data.emergencyContact2);
  setIfDefined(cols.EMERGENCY_PHONE2, data.emergencyPhone2);

  // 住所情報
  setIfDefined(cols.POSTAL_CODE, data.postalCode);
  setIfDefined(cols.PREFECTURE, data.prefecture);
  setIfDefined(cols.CITY, data.city);
  setIfDefined(cols.WARD, data.ward);
  setIfDefined(cols.ADDRESS, data.address);
  setIfDefined(cols.ADDRESS2, data.address2);

  // 詳細情報
  setIfDefined(cols.BIRTH_DATE, data.birthDate);
  setIfDefined(cols.LIFE_PROTECTION, data.lifeProtection);
  setIfDefined(cols.DISABILITY_PENSION, data.disabilityPension);
  setIfDefined(cols.DISABILITY_NUMBER, data.disabilityNumber);
  setIfDefined(cols.DISABILITY_GRADE, data.disabilityGrade);
  setIfDefined(cols.DISABILITY_TYPE, data.disabilityType);
  setIfDefined(cols.HANDBOOK_VALID, data.handbookValid);
  setIfDefined(cols.MUNICIPAL_NUMBER, data.municipalNumber);
  setIfDefined(cols.CERTIFICATE_NUMBER, data.certificateNumber);
  setIfDefined(cols.DECISION_PERIOD1, data.decisionPeriod1);
  setIfDefined(cols.DECISION_PERIOD2, data.decisionPeriod2);
  setIfDefined(cols.APPLICABLE_START, data.applicableStart);
  setIfDefined(cols.APPLICABLE_END, data.applicableEnd);
  setIfDefined(cols.SUPPLY_AMOUNT, data.supplyAmount);
  setIfDefined(cols.SUPPORT_LEVEL, data.supportLevel);
  setIfDefined(cols.USE_START_DATE, data.useStartDate);

  // 期間計算（AI列・AJ列は自動計算列のため書き込まない）

  // 受給者証情報（AK列）
  setIfDefined(cols.USER_BURDEN_LIMIT, data.userBurdenLimit);

  // 相談支援事業所
  setIfDefined(cols.CONSULTATION_FACILITY, data.consultationFacility);
  setIfDefined(cols.CONSULTATION_STAFF, data.consultationStaff);
  setIfDefined(cols.CONSULTATION_CONTACT, data.consultationContact);

  // グループホーム
  setIfDefined(cols.GH_FACILITY, data.ghFacility);
  setIfDefined(cols.GH_STAFF, data.ghStaff);
  setIfDefined(cols.GH_CONTACT, data.ghContact);

  // その他関係機関
  setIfDefined(cols.OTHER_FACILITY, data.otherFacility);
  setIfDefined(cols.OTHER_STAFF, data.otherStaff);
  setIfDefined(cols.OTHER_CONTACT, data.otherContact);

  // 工賃振込先情報
  setIfDefined(cols.BANK_NAME, data.bankName);
  setIfDefined(cols.BANK_CODE, data.bankCode);
  setIfDefined(cols.BRANCH_NAME, data.branchName);
  setIfDefined(cols.BRANCH_CODE, data.branchCode);
  setIfDefined(cols.ACCOUNT_NUMBER, data.accountNumber);

  // 退所・就労情報
  setIfDefined(cols.LEAVE_DATE, data.leaveDate);
  setIfDefined(cols.LEAVE_REASON, data.leaveReason);
  setIfDefined(cols.WORK_NAME, data.workName);
  setIfDefined(cols.WORK_CONTACT, data.workContact);
  setIfDefined(cols.WORK_CONTENT, data.workContent);
  setIfDefined(cols.CONTRACT_TYPE, data.contractType);
  setIfDefined(cols.EMPLOYMENT_SUPPORT, data.employmentSupport);
  setIfDefined(cols.NOTES, data.notes);

  // 一括書き込み（1回のAPI呼び出しで60列分を書き込み）
  rosterSheet.getRange(rowNumber, 1, 1, maxCol).setValues([rowData]);
}

/**
 * 名簿_2025シートから利用者データを削除
 */
function deleteFromRosterSheet(rosterSheet, name) {
  // 名簿_2025シートの3行目から利用者名を一括取得して検索
  const lastRow = rosterSheet.getLastRow();
  const numRows = Math.max(0, lastRow - 2);

  if (numRows > 0) {
    const nameData = rosterSheet.getRange(3, ROSTER_COLS.NAME, numRows, 1).getValues();
    for (let i = 0; i < nameData.length; i++) {
      if (nameData[i][0] === name) {
        // 該当行の全列をクリア
        rosterSheet.getRange(3 + i, 1, 1, 60).clearContent();
        return true;
      }
    }
  }
  return false;
}

/**
 * 利用者一覧を取得（全員：契約中 + 退所済み）
 * 一括取得で高速化
 */
function handleGetUserList() {
  try {
    const sheet = getSheet(SHEET_NAMES.MASTER);
    const rosterSheet = getSheet(SHEET_NAMES.ROSTER);
    const startRow = MASTER_CONFIG.USER_DATA_START_ROW;
    const numRows = 200 - startRow + 1; // 8〜200行

    // マスタ設定シートからA〜J列を一括取得
    const masterData = sheet.getRange(startRow, 1, numRows, 10).getValues();

    // 名簿シートから全データを一括取得（3行目〜最終行、A〜BH列=60列）
    const rosterLastRow = rosterSheet.getLastRow();
    const rosterNumRows = Math.max(0, rosterLastRow - 2);
    let rosterMap = {};

    if (rosterNumRows > 0) {
      const rosterData = rosterSheet.getRange(3, 1, rosterNumRows, 60).getValues();
      // 名前をキーにしたマップを作成（行番号も保持）
      for (let i = 0; i < rosterData.length; i++) {
        const name = rosterData[i][ROSTER_COLS.NAME - 1]; // B列 = index 1
        if (name) {
          rosterMap[name] = { rowIndex: i, rowNumber: i + 3, data: rosterData[i] };
        }
      }
    }

    const userList = [];
    const cols = MASTER_CONFIG.USER_COLS;

    for (let i = 0; i < masterData.length; i++) {
      const row = masterData[i];
      const name = row[cols.NAME - 1];      // A列
      const furigana = row[cols.FURIGANA - 1]; // B列

      // 空白行に達したら終了
      if (!name || name === '') {
        break;
      }

      // 名前とフリガナが両方入力されている行のみ取得
      if (furigana) {
        const userObj = {
          name: name,
          furigana: furigana,
          status: row[cols.STATUS - 1] || '契約中',
          scheduledMon: row[cols.SCHEDULED_MON - 1] || '',
          scheduledTue: row[cols.SCHEDULED_TUE - 1] || '',
          scheduledWed: row[cols.SCHEDULED_WED - 1] || '',
          scheduledThu: row[cols.SCHEDULED_THU - 1] || '',
          scheduledFri: row[cols.SCHEDULED_FRI - 1] || '',
          scheduledSat: row[cols.SCHEDULED_SAT - 1] || '',
          scheduledSun: row[cols.SCHEDULED_SUN - 1] || '',
          rowNumber: startRow + i
        };

        // 名簿シートにデータがある場合、詳細情報を追加
        const rosterInfo = rosterMap[name];
        if (rosterInfo) {
          const r = rosterInfo.data;
          const rc = ROSTER_COLS;

          userObj.rosterRowNumber = rosterInfo.rowNumber;

          // 連絡先情報
          userObj.mobilePhone = r[rc.MOBILE_PHONE - 1] || '';
          userObj.chatworkId = r[rc.CHATWORK_ID - 1] || '';
          userObj.mail = r[rc.MAIL - 1] || '';
          userObj.emergencyContact1 = r[rc.EMERGENCY_CONTACT1 - 1] || '';
          userObj.emergencyPhone1 = r[rc.EMERGENCY_PHONE1 - 1] || '';
          userObj.emergencyContact2 = r[rc.EMERGENCY_CONTACT2 - 1] || '';
          userObj.emergencyPhone2 = r[rc.EMERGENCY_PHONE2 - 1] || '';

          // 住所情報
          userObj.postalCode = r[rc.POSTAL_CODE - 1] || '';
          userObj.prefecture = r[rc.PREFECTURE - 1] || '';
          userObj.city = r[rc.CITY - 1] || '';
          userObj.ward = r[rc.WARD - 1] || '';
          userObj.address = r[rc.ADDRESS - 1] || '';
          userObj.address2 = r[rc.ADDRESS2 - 1] || '';

          // 詳細情報
          userObj.birthDate = r[rc.BIRTH_DATE - 1] || '';
          userObj.lifeProtection = r[rc.LIFE_PROTECTION - 1] || '';
          userObj.disabilityPension = r[rc.DISABILITY_PENSION - 1] || '';
          userObj.disabilityNumber = r[rc.DISABILITY_NUMBER - 1] || '';
          userObj.disabilityGrade = r[rc.DISABILITY_GRADE - 1] || '';
          userObj.disabilityType = r[rc.DISABILITY_TYPE - 1] || '';
          userObj.handbookValid = r[rc.HANDBOOK_VALID - 1] || '';
          userObj.municipalNumber = r[rc.MUNICIPAL_NUMBER - 1] || '';
          userObj.certificateNumber = r[rc.CERTIFICATE_NUMBER - 1] || '';
          userObj.decisionPeriod1 = r[rc.DECISION_PERIOD1 - 1] || '';
          userObj.decisionPeriod2 = r[rc.DECISION_PERIOD2 - 1] || '';
          userObj.applicableStart = r[rc.APPLICABLE_START - 1] || '';
          userObj.applicableEnd = r[rc.APPLICABLE_END - 1] || '';
          userObj.supplyAmount = r[rc.SUPPLY_AMOUNT - 1] || '';
          userObj.supportLevel = r[rc.SUPPORT_LEVEL - 1] || '';
          userObj.useStartDate = r[rc.USE_START_DATE - 1] || '';

          // 期間計算
          userObj.initialAddition = r[rc.INITIAL_ADDITION - 1] || '';

          // 受給者証情報（AK列）
          userObj.userBurdenLimit = r[rc.USER_BURDEN_LIMIT - 1] || '';

          // 相談支援事業所
          userObj.consultationFacility = r[rc.CONSULTATION_FACILITY - 1] || '';
          userObj.consultationStaff = r[rc.CONSULTATION_STAFF - 1] || '';
          userObj.consultationContact = r[rc.CONSULTATION_CONTACT - 1] || '';

          // グループホーム
          userObj.ghFacility = r[rc.GH_FACILITY - 1] || '';
          userObj.ghStaff = r[rc.GH_STAFF - 1] || '';
          userObj.ghContact = r[rc.GH_CONTACT - 1] || '';

          // その他関係機関
          userObj.otherFacility = r[rc.OTHER_FACILITY - 1] || '';
          userObj.otherStaff = r[rc.OTHER_STAFF - 1] || '';
          userObj.otherContact = r[rc.OTHER_CONTACT - 1] || '';

          // 工賃振込先情報
          userObj.bankName = r[rc.BANK_NAME - 1] || '';
          userObj.bankCode = r[rc.BANK_CODE - 1] || '';
          userObj.branchName = r[rc.BRANCH_NAME - 1] || '';
          userObj.branchCode = r[rc.BRANCH_CODE - 1] || '';
          userObj.accountNumber = r[rc.ACCOUNT_NUMBER - 1] || '';

          // 退所・就労情報
          userObj.leaveDate = r[rc.LEAVE_DATE - 1] || '';
          userObj.leaveReason = r[rc.LEAVE_REASON - 1] || '';
          userObj.workName = r[rc.WORK_NAME - 1] || '';
          userObj.workContact = r[rc.WORK_CONTACT - 1] || '';
          userObj.workContent = r[rc.WORK_CONTENT - 1] || '';
          userObj.contractType = r[rc.CONTRACT_TYPE - 1] || '';
          userObj.employmentSupport = r[rc.EMPLOYMENT_SUPPORT - 1] || '';
          userObj.notes = r[rc.NOTES - 1] || '';
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
 * 一括取得・一括書き込みで高速化
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
    const cols = MASTER_CONFIG.USER_COLS;
    const startRow = MASTER_CONFIG.USER_DATA_START_ROW;
    const numRows = 200 - startRow + 1;

    // マスタ設定シートのA列（名前）を一括取得
    const nameData = sheet.getRange(startRow, cols.NAME, numRows, 1).getValues();

    // 名前の重複チェックと空行探しを同時に実行
    let newRow = -1;
    for (let i = 0; i < nameData.length; i++) {
      const existingName = nameData[i][0];

      // 名前重複チェック
      if (existingName && existingName === data.name) {
        return createErrorResponse('この利用者名は既に登録されています');
      }

      // 空行を探す（最初に見つかった空行を記録）
      if (newRow === -1 && (!existingName || existingName === '')) {
        newRow = startRow + i;
      }
    }

    // 空行が見つからなければ最後に追加
    if (newRow === -1) {
      newRow = startRow + nameData.length;
    }

    // マスタ設定シートにデータを一括書き込み（A〜J列）
    const masterWriteData = [[
      data.name,
      data.furigana,
      data.status,
      data.scheduledMon || '',
      data.scheduledTue || '',
      data.scheduledWed || '',
      data.scheduledThu || '',
      data.scheduledFri || '',
      data.scheduledSat || '',
      data.scheduledSun || ''
    ]];
    sheet.getRange(newRow, cols.NAME, 1, 10).setValues(masterWriteData);

    // 名簿_2025シートにも書き込む
    const rosterSheet = getSheet(SHEET_NAMES.ROSTER);
    const rosterLastRow = rosterSheet.getLastRow();
    const rosterNumRows = Math.max(0, rosterLastRow - 2);

    // 名簿シートのB列（名前）を一括取得
    let rosterRow = 3;
    if (rosterNumRows > 0) {
      const rosterNameData = rosterSheet.getRange(3, ROSTER_COLS.NAME, rosterNumRows, 1).getValues();
      rosterRow = rosterLastRow + 1; // デフォルトは最後

      for (let i = 0; i < rosterNameData.length; i++) {
        const existingName = rosterNameData[i][0];
        if (!existingName || existingName === '') {
          rosterRow = 3 + i;
          break;
        }
      }
    }

    // 名簿シートにデータを書き込む
    writeToRosterSheetBatch(rosterSheet, rosterRow, data);

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

    // 退所日が入力されている場合は自動的に契約状態を「退所済み」に変更
    if (data.leaveDate && data.leaveDate !== '') {
      data.status = '退所済み';
    }

    const sheet = getSheet(SHEET_NAMES.MASTER);
    const cols = MASTER_CONFIG.USER_COLS;
    const startRow = MASTER_CONFIG.USER_DATA_START_ROW;
    const numRows = 200 - startRow + 1;

    // マスタ設定シートのA列（名前）を一括取得
    const nameData = sheet.getRange(startRow, cols.NAME, numRows, 1).getValues();

    // 元の利用者名を取得（名簿シート更新のため）
    const originalName = nameData[data.rowNumber - startRow][0];

    // 名前重複チェック（自分自身の行は除外）
    for (let i = 0; i < nameData.length; i++) {
      const actualRow = startRow + i;
      if (actualRow === data.rowNumber) continue; // 自分自身はスキップ

      const existingName = nameData[i][0];
      if (existingName && existingName === data.name) {
        return createErrorResponse('この利用者名は既に登録されています');
      }
    }

    // マスタ設定シートにデータを一括書き込み（A〜J列）
    const masterWriteData = [[
      data.name,
      data.furigana,
      data.status,
      data.scheduledMon || '',
      data.scheduledTue || '',
      data.scheduledWed || '',
      data.scheduledThu || '',
      data.scheduledFri || '',
      data.scheduledSat || '',
      data.scheduledSun || ''
    ]];
    sheet.getRange(data.rowNumber, cols.NAME, 1, 10).setValues(masterWriteData);

    // 名簿_2025シートも更新
    const rosterSheet = getSheet(SHEET_NAMES.ROSTER);
    const rosterLastRow = rosterSheet.getLastRow();
    const rosterNumRows = Math.max(0, rosterLastRow - 2);

    // 名簿シートのB列（名前）を一括取得して行を検索
    let rosterRow = -1;
    if (rosterNumRows > 0) {
      const rosterNameData = rosterSheet.getRange(3, ROSTER_COLS.NAME, rosterNumRows, 1).getValues();
      for (let i = 0; i < rosterNameData.length; i++) {
        if (rosterNameData[i][0] === originalName) {
          rosterRow = 3 + i;
          break;
        }
      }
    }

    // 名簿シートの行が見つかった場合のみ更新
    if (rosterRow !== -1) {
      writeToRosterSheetBatch(rosterSheet, rosterRow, data);
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
    const rosterNumRows = Math.max(0, rosterLastRow - 2);

    // 名簿シートのB列（名前）を一括取得して行を検索
    if (rosterNumRows > 0) {
      const rosterNameData = rosterSheet.getRange(3, ROSTER_COLS.NAME, rosterNumRows, 1).getValues();
      for (let i = 0; i < rosterNameData.length; i++) {
        if (rosterNameData[i][0] === userName) {
          const rosterRow = 3 + i;
          // 名簿シートのステータスと退所日を一括更新
          const leaveDate = (data.status === '退所済み' && data.leaveDate)
            ? data.leaveDate
            : (data.status === '契約中' ? '' : null);

          // ステータス更新
          rosterSheet.getRange(rosterRow, ROSTER_COLS.STATUS).setValue(data.status);

          // 退所日も更新（必要な場合）
          if (leaveDate !== null) {
            rosterSheet.getRange(rosterRow, ROSTER_COLS.LEAVE_DATE).setValue(leaveDate);
          }

          break;
        }
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
    const cols = MASTER_CONFIG.USER_COLS;

    // 削除前に利用者名を取得（名簿シート削除のため）
    const userName = sheet.getRange(data.rowNumber, cols.NAME).getValue();

    // マスタ設定シートのA-J列のデータを一括クリア（10列）
    sheet.getRange(data.rowNumber, cols.NAME, 1, 10).clearContent();

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
        const scheduledValueStr = String(scheduledValue).trim();

        // 契約中かつ出勤予定がある利用者のみ（非利用日は除外）
        if (status === '契約中' && scheduledValue && scheduledValue !== '' &&
            !scheduledValueStr.includes('非利用') && scheduledValueStr !== '非利用日') {
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
      // レコードがない場合は新規作成（欠席登録などに対応）
      return createAttendanceRecord(sheet, date, userName, data);
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
 * 勤怠レコードを新規作成（支援者による欠席登録など）
 */
function createAttendanceRecord(sheet, date, userName, data) {
  try {
    // A列が空欄の最上行を探す
    const lastRow = sheet.getLastRow();
    const maxRow = Math.max(lastRow, 200);
    const dateColumn = sheet.getRange(2, SUPPORT_COLS.DATE, maxRow - 1, 1).getValues();

    let newRow = 2;
    for (let i = 0; i < dateColumn.length; i++) {
      if (dateColumn[i][0] === '' || dateColumn[i][0] === null) {
        newRow = i + 2;
        break;
      }
    }

    if (newRow === 2 && dateColumn[0][0] !== '' && dateColumn[0][0] !== null) {
      newRow = maxRow + 1;
    }

    // マスタ設定シートから曜日別出欠予定を自動取得
    const scheduledAttendance = getUserScheduledAttendance(userName, date);
    const scheduledValue = scheduledAttendance || '';

    // 新規レコードを作成
    const rowData = [
      date,                              // A列: 日時
      userName,                          // B列: 利用者名
      scheduledValue,                    // C列: 出欠（予定）
      data.attendanceStatus || '',       // D列: 出欠（実績）
      '',                                // E列: 担当業務AM
      '',                                // F列: 担当業務PM
      '',                                // G列: 業務連絡
      '',                                // H列: 本日の体調
      '',                                // I列: 睡眠状況
      '',                                // J列: 出勤時コメント
      '',                                // K列: 疲労感
      '',                                // L列: 心理的負荷
      '',                                // M列: 退勤時コメント
      '',                                // N列: （予備）
      '',                                // O列: （予備）
      data.checkinTime || '',            // P列: 勤務開始時刻
      data.checkoutTime || '',           // Q列: 勤務終了時刻
      data.lunchBreak || '',             // R列: 昼休憩
      data.shortBreak || '',             // S列: 15分休憩
      data.otherBreak || '',             // T列: 他休憩時間
      0                                  // U列: 実労時間
    ];

    // A列〜U列を一括入力（21列）
    sheet.getRange(newRow, SUPPORT_COLS.DATE, 1, 21).setValues([rowData]);

    return createSuccessResponse({
      message: '勤怠データを登録しました',
      rowId: newRow,
      created: true
    });
  } catch (error) {
    return createErrorResponse('勤怠データ登録エラー: ' + error.message);
  }
}

/**
 * 利用者の過去記録一覧を取得（高速版）
 * 直近データから検索し、最大50件を返す
 */
function handleGetUserHistory(userName) {
  try {
    const sheet = getSheet(SHEET_NAMES.SUPPORT);

    // 実データの最下行を取得
    const actualLastRow = findActualLastRow(sheet, SUPPORT_COLS.USER_NAME);

    if (actualLastRow < 2) {
      return createSuccessResponse({ records: [] });
    }

    const MAX_RECORDS = 50;      // 最大取得件数
    const MAX_SEARCH_ROWS = 500; // 最大検索行数

    // 直近500行のみ検索（高速化）
    const searchRows = Math.min(actualLastRow - 1, MAX_SEARCH_ROWS);
    const startRow = Math.max(2, actualLastRow - searchRows + 1);

    // 必要な列のみ取得（高速化）: 日付、利用者名、出欠、出勤時間、退勤時間、実労時間、支援記録
    const colsToFetch = 38; // 全列取得（parseAttendanceRowFromArrayで必要）
    const allData = sheet.getRange(startRow, 1, searchRows, colsToFetch).getValues();
    const records = [];

    // 逆順（新しい順）で検索し、最大件数まで取得
    for (let i = allData.length - 1; i >= 0 && records.length < MAX_RECORDS; i--) {
      const rowUserName = allData[i][SUPPORT_COLS.USER_NAME - 1];

      // 利用者名が一致する行のみ処理
      if (rowUserName && String(rowUserName) === userName) {
        const rowNumber = startRow + i;
        records.push(parseAttendanceRowFromArray(allData[i], rowNumber));
      }
    }

    // 既に新しい順になっているのでソート不要

    return createSuccessResponse({ records });
  } catch (error) {
    return createErrorResponse('履歴取得エラー: ' + error.message);
  }
}

/**
 * 複数利用者の健康履歴をバッチ取得（カード表示用）
 * 各利用者の直近7回分の健康データ（日付、体調）のみ返す
 * ※高速化のため、検索範囲を150行に制限し、必要最小限の列のみ取得
 * ※キャッシュ機能により、5分間は同じデータを再利用
 */
function handleGetHealthBatch(userNames) {
  try {
    if (!userNames || userNames.length === 0) {
      return createSuccessResponse({ healthData: {} });
    }

    // キャッシュキーを生成
    const cacheKey = getHealthBatchCacheKey(userNames);

    // キャッシュからデータを取得
    const cachedData = getCacheData(cacheKey);
    if (cachedData) {
      return createSuccessResponse({ healthData: cachedData, cached: true });
    }

    const sheet = getSheet(SHEET_NAMES.SUPPORT);
    const actualLastRow = findActualLastRow(sheet, SUPPORT_COLS.USER_NAME);

    if (actualLastRow < 2) {
      return createSuccessResponse({ healthData: {} });
    }

    const MAX_RECORDS_PER_USER = 7;
    const MAX_SEARCH_ROWS = 150; // 高速化のため150行に削減

    // 検索対象の行範囲を決定
    const searchRows = Math.min(actualLastRow - 1, MAX_SEARCH_ROWS);
    const startRow = Math.max(2, actualLastRow - searchRows + 1);

    // 必要な列のみ取得（A:日付, B:利用者名, H:体調）= 8列のみ
    const colsToFetch = 8;
    const allData = sheet.getRange(startRow, 1, searchRows, colsToFetch).getValues();

    // 対象ユーザーをSetに変換（高速検索用）
    const targetUsers = new Set(userNames);
    const userCount = userNames.length;
    let completedUsers = 0;

    // 結果を格納するオブジェクト
    const healthData = {};
    userNames.forEach(name => { healthData[name] = []; });

    // 逆順（新しい順）で検索
    for (let i = allData.length - 1; i >= 0 && completedUsers < userCount; i--) {
      const rowUserName = String(allData[i][SUPPORT_COLS.USER_NAME - 1] || '');

      if (targetUsers.has(rowUserName)) {
        const userRecords = healthData[rowUserName];
        if (userRecords.length < MAX_RECORDS_PER_USER) {
          const date = allData[i][SUPPORT_COLS.DATE - 1];
          const dateStr = date instanceof Date
            ? Utilities.formatDate(date, 'Asia/Tokyo', 'yyyy/MM/dd')
            : String(date || '');

          userRecords.push({
            date: dateStr,
            healthCondition: String(allData[i][SUPPORT_COLS.HEALTH - 1] || '')
          });

          if (userRecords.length >= MAX_RECORDS_PER_USER) {
            completedUsers++;
          }
        }
      }
    }

    // キャッシュに保存（5分間有効）
    setCacheData(cacheKey, healthData, 300);

    return createSuccessResponse({ healthData, cached: false });
  } catch (error) {
    return createErrorResponse('健康履歴バッチ取得エラー: ' + error.message);
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
    transportService: rowData[SUPPORT_COLS.TRANSPORT - 1] || false,
    userStatus: toStringOrNull(rowData[SUPPORT_COLS.USER_STATUS - 1])  // Z列: 本人の状況
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
    transportService: sheet.getRange(row, SUPPORT_COLS.TRANSPORT).getValue() || false,
    userStatus: toStringOrNull(sheet.getRange(row, SUPPORT_COLS.USER_STATUS).getValue())  // Z列: 本人の状況
  };
}

// === ヘルパー関数 ===

// === キャッシュ関連 ===

/**
 * キャッシュからデータを取得
 * @param {string} key - キャッシュキー
 * @returns {Object|null} キャッシュされたデータ、またはnull
 */
function getCacheData(key) {
  try {
    const cache = CacheService.getScriptCache();
    const cached = cache.get(key);
    if (cached) {
      return JSON.parse(cached);
    }
    return null;
  } catch (error) {
    console.log('キャッシュ取得エラー: ' + error.message);
    return null;
  }
}

/**
 * キャッシュにデータを保存
 * @param {string} key - キャッシュキー
 * @param {Object} data - 保存するデータ
 * @param {number} ttl - キャッシュ有効期間（秒）、デフォルト300秒（5分）
 */
function setCacheData(key, data, ttl = 300) {
  try {
    const cache = CacheService.getScriptCache();
    cache.put(key, JSON.stringify(data), ttl);
  } catch (error) {
    console.log('キャッシュ保存エラー: ' + error.message);
  }
}

/**
 * 特定のキャッシュを削除
 * @param {string} key - 削除するキャッシュキー
 */
function deleteCacheData(key) {
  try {
    const cache = CacheService.getScriptCache();
    cache.remove(key);
  } catch (error) {
    console.log('キャッシュ削除エラー: ' + error.message);
  }
}

/**
 * health-batch用のキャッシュキーを生成
 * @param {Array} userNames - ユーザー名の配列
 * @returns {string} キャッシュキー
 */
function getHealthBatchCacheKey(userNames) {
  // ユーザー名をソートして一貫したキーを生成
  const sortedNames = userNames.slice().sort();
  return 'health_batch_' + sortedNames.join('_').substring(0, 200);
}

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
 * 日付フォーマット（YYYY-MM-DD形式）
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
 * 日付フォーマット（YYYYMMDD形式）
 */
function formatDateYYYYMMDD(dateValue) {
  if (!dateValue) return '';

  // 既にYYYYMMDD形式の文字列の場合
  const str = String(dateValue);
  if (str.match(/^\d{8}$/)) return str;

  // YYYY-MM-DD形式の場合
  if (str.match(/^\d{4}-\d{2}-\d{2}$/)) {
    return str.replace(/-/g, '');
  }

  // 日付オブジェクトの場合
  const date = new Date(dateValue);
  if (isNaN(date.getTime())) return '';

  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');

  return `${year}${month}${day}`;
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

// ========================================
// Chatwork関連機能
// ========================================

/**
 * ChatWorkルームIDを持つ利用者一覧を取得
 * 【最適化】一括取得で高速化
 */
function handleGetChatworkUsers() {
  try {
    const rosterSheet = getSheet(SHEET_NAMES.ROSTER);
    const lastRow = rosterSheet.getLastRow();
    if (lastRow < 3) {
      return createSuccessResponse({ users: [] });
    }

    // 一括取得: B列(氏名)とG列(ChatWorkルームID)
    const dataRange = rosterSheet.getRange(3, 1, lastRow - 2, 7);
    const allData = dataRange.getValues();

    const users = [];
    for (let i = 0; i < allData.length; i++) {
      const name = allData[i][1];  // B列: 氏名
      const roomId = allData[i][6]; // G列: ChatWorkルームID

      if (name && name !== '') {
        users.push({
          userName: name,
          chatworkRoomId: roomId || ''
        });
      }
    }

    return createSuccessResponse({ users: users });
  } catch (error) {
    return createErrorResponse('Chatwork利用者取得エラー: ' + error.message);
  }
}

/**
 * Chatworkメッセージ送信（選択送信対応）
 * 【最適化】APIキーはPropertiesServiceから取得、一括データ取得
 */
function handleChatworkBroadcast(data) {
  try {
    const message = data.message;
    if (!message) {
      return createErrorResponse('メッセージが指定されていません');
    }

    // 選択された利用者リスト（指定されていない場合は全員）
    const selectedUsers = data.selectedUsers || null;
    const selectedSet = selectedUsers ? new Set(selectedUsers) : null;

    // APIキーをPropertiesServiceから取得
    const apiKey = PropertiesService.getScriptProperties().getProperty('CHATWORK_API_KEY');
    if (!apiKey) {
      return createErrorResponse('ChatWork APIキーが設定されていません');
    }

    // ルームIDを持つ利用者を一括取得
    const rosterSheet = getSheet(SHEET_NAMES.ROSTER);
    const lastRow = rosterSheet.getLastRow();
    if (lastRow < 3) {
      return createSuccessResponse({ sentCount: 0, failedCount: 0 });
    }

    const dataRange = rosterSheet.getRange(3, 1, lastRow - 2, 7);
    const allData = dataRange.getValues();

    let sentCount = 0;
    let failedCount = 0;
    const errors = [];

    for (let i = 0; i < allData.length; i++) {
      const name = allData[i][1];  // B列: 氏名
      const roomId = allData[i][6]; // G列: ChatWorkルームID

      // 選択送信の場合、選択された利用者のみ対象
      if (selectedSet && !selectedSet.has(name)) {
        continue;
      }

      if (name && roomId && roomId !== '') {
        try {
          const url = 'https://api.chatwork.com/v2/rooms/' + roomId + '/messages';
          const options = {
            method: 'post',
            headers: { 'X-ChatWorkToken': apiKey },
            payload: { body: message },
            muteHttpExceptions: true
          };

          const response = UrlFetchApp.fetch(url, options);
          const responseCode = response.getResponseCode();
          if (responseCode === 200) {
            sentCount++;
          } else {
            failedCount++;
            const errorDetail = name + ': ' + responseCode + ' - ' + response.getContentText();
            errors.push(errorDetail);
            Logger.log('Chatwork送信失敗: ' + errorDetail);
          }
        } catch (e) {
          failedCount++;
          errors.push(name + ': ' + e.message);
          Logger.log('Chatwork送信エラー (' + name + '): ' + e.message);
        }
      }
    }

    return createSuccessResponse({
      sentCount: sentCount,
      failedCount: failedCount,
      errors: errors
    });
  } catch (error) {
    return createErrorResponse('Chatwork送信エラー: ' + error.message);
  }
}

/**
 * ChatWork APIキーを設定
 */
function handleSetChatworkApiKey(data) {
  try {
    const apiKey = data.apiKey;
    if (!apiKey) {
      return createErrorResponse('APIキーが指定されていません');
    }

    PropertiesService.getScriptProperties().setProperty('CHATWORK_API_KEY', apiKey);

    return createSuccessResponse({ message: 'APIキーを設定しました' });
  } catch (error) {
    return createErrorResponse('APIキー設定エラー: ' + error.message);
  }
}

// =============================================
// 分析機能（Analytics）
// =============================================

/**
 * 施設全体の統計を取得
 * @param {string} [monthStr] - 対象月（YYYY-MM形式）。省略時は当月
 */
function handleGetFacilityStats(monthStr) {
  try {
    const masterSheet = getSheet(SHEET_NAMES.MASTER);
    const supportSheet = getSheet(SHEET_NAMES.SUPPORT);
    const rosterSheet = getSheet(SHEET_NAMES.ROSTER);

    // 対象月の範囲を計算
    let year, month;
    if (monthStr && monthStr.match(/^\d{4}-\d{2}$/)) {
      const parts = monthStr.split('-');
      year = parseInt(parts[0], 10);
      month = parseInt(parts[1], 10);
    } else {
      const now = new Date();
      year = now.getFullYear();
      month = now.getMonth() + 1;
    }
    const firstDay = new Date(year, month - 1, 1);
    const lastDay = new Date(year, month, 0);

    // 当月かどうか
    const now = new Date();
    const isCurrentMonth = (year === now.getFullYear() && month === now.getMonth() + 1);

    // 利用者数を取得（当月は契約中、過去月は退所日を考慮）
    let totalUsers = 0;
    const masterLastRow = masterSheet.getLastRow();

    // 名簿から利用者数をカウント（契約中 + 当月退所者のみ）
    const rosterLastRow = rosterSheet.getLastRow();
    if (rosterLastRow >= 3) {
      const numRows = rosterLastRow - 2;
      // 名前(B列)、ステータス(E列)、退所日(BA列)を取得
      const nameData = rosterSheet.getRange(3, ROSTER_COLS.NAME, numRows, 1).getValues();
      const statusData = rosterSheet.getRange(3, ROSTER_COLS.STATUS, numRows, 1).getValues();
      const leaveDateData = rosterSheet.getRange(3, ROSTER_COLS.LEAVE_DATE, numRows, 1).getValues();

      for (let i = 0; i < numRows; i++) {
        const name = nameData[i][0];
        if (!name || name === '') continue;

        const status = statusData[i][0];
        const leaveDate = leaveDateData[i][0];

        if (status === '契約中') {
          // 契約中はカウント
          totalUsers++;
        } else if (status === '退所済み' && leaveDate) {
          // 退所者は退所月のみカウント（翌月以降は除外）
          let leaveDateObj;
          const rawStr = String(leaveDate);
          if (rawStr.match(/^\d{8}$/)) {
            // YYYYMMDD形式
            const y = parseInt(rawStr.substring(0, 4), 10);
            const m = parseInt(rawStr.substring(4, 6), 10) - 1;
            const d = parseInt(rawStr.substring(6, 8), 10);
            leaveDateObj = new Date(y, m, d);
          } else {
            leaveDateObj = new Date(leaveDate);
          }
          // 退所日が対象月内であればカウント
          if (leaveDateObj >= firstDay && leaveDateObj <= lastDay) {
            totalUsers++;
          }
        }
      }
    }

    // 対象月の出勤データを集計
    const actualLastRow = findActualLastRow(supportSheet, SUPPORT_COLS.USER_NAME);
    let monthlyAttendance = 0;
    let totalScheduled = 0;
    const workDays = new Set();

    if (actualLastRow >= 2) {
      // 過去月の場合は全データを検索する必要がある可能性
      const MAX_SEARCH_ROWS = isCurrentMonth ? 1000 : 3000;
      const searchRows = Math.min(actualLastRow - 1, MAX_SEARCH_ROWS);
      const startRow = Math.max(2, actualLastRow - searchRows + 1);

      // 日付、利用者名、出欠予定、出欠を一括取得
      const data = supportSheet.getRange(startRow, SUPPORT_COLS.DATE, searchRows, 4).getValues();

      for (let i = 0; i < data.length; i++) {
        const dateVal = data[i][0];
        if (!dateVal) continue;

        const rowDate = new Date(dateVal);
        // 対象月のデータのみ集計
        if (rowDate >= firstDay && rowDate <= lastDay) {
          const userName = data[i][1];
          if (!userName || userName === '') continue;

          const scheduled = data[i][2];
          const attendance = data[i][3];

          // 出欠予定がある場合カウント
          if (scheduled && scheduled !== '') {
            totalScheduled++;
          }

          // 出欠に何か入力があれば稼働日としてカウント
          if (attendance && attendance !== '') {
            const dateStr = formatDate(dateVal);
            workDays.add(dateStr);
          }

          // 出勤・在宅・施設外・遅刻・早退の場合、出勤延べ数としてカウント
          if (attendance === '出勤' || attendance === '在宅' || attendance === '施設外' || attendance === '遅刻' || attendance === '早退') {
            monthlyAttendance++;
          }
        }
      }
    }

    // 出勤率を計算
    const attendanceRate = totalScheduled > 0 ? monthlyAttendance / totalScheduled : 0;

    return createSuccessResponse({
      year: year,
      month: month,
      totalUsers: totalUsers,
      attendanceRate: attendanceRate,
      monthlyWorkDays: workDays.size,
      monthlyAttendance: monthlyAttendance
    });
  } catch (error) {
    return createErrorResponse('施設統計取得エラー: ' + error.message);
  }
}

/**
 * 曜日別出勤予定を取得
 */
function handleGetWeeklySchedule() {
  try {
    const masterSheet = getSheet(SHEET_NAMES.MASTER);

    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];

    // 曜日別のカウント初期化
    const schedule = {};
    const details = {};  // 詳細データ（元の値ごとのカウント）
    weekdays.forEach(day => {
      schedule[day] = { '本施設': 0, '施設外': 0, '在宅': 0 };
      details[day] = { '本施設': {}, '施設外': {}, '在宅': {} };
    });

    const weekdayMap = {
      4: '月', // D列
      5: '火', // E列
      6: '水', // F列
      7: '木', // G列
      8: '金', // H列
      9: '土', // I列
      10: '日' // J列
    };

    const masterLastRow = masterSheet.getLastRow();
    if (masterLastRow >= MASTER_CONFIG.USER_DATA_START_ROW) {
      const startRow = MASTER_CONFIG.USER_DATA_START_ROW;
      const numRows = masterLastRow - startRow + 1;

      // 名前(A列)、ステータス(C列)、曜日別予定(D-J列)を一括取得
      const data = masterSheet.getRange(startRow, 1, numRows, 10).getValues();

      for (let i = 0; i < data.length; i++) {
        const name = data[i][0];
        if (!name || name === '') break;

        const status = data[i][2]; // C列: ステータス
        if (status !== '契約中') continue;

        // D列〜J列（曜日別予定）をチェック
        for (let col = 3; col <= 9; col++) { // 配列インデックス3-9 = D-J列
          const value = data[i][col];
          if (!value || value === '') continue;

          const weekday = weekdayMap[col + 1]; // 配列インデックス+1 = 列番号
          const valueStr = String(value).trim();

          // 「非利用日」は除外
          if (valueStr.includes('非利用') || valueStr === '非利用日') continue;

          // 値に基づいて分類
          let category = '';
          if (valueStr.includes('施設外') || valueStr.includes('外')) {
            category = '施設外';
          } else if (valueStr.includes('在宅') || valueStr.includes('自宅')) {
            category = '在宅';
          } else if (valueStr !== '') {
            category = '本施設';
          }

          if (category) {
            schedule[weekday][category]++;
            // 詳細データに元の値をカウント
            if (!details[weekday][category][valueStr]) {
              details[weekday][category][valueStr] = 0;
            }
            details[weekday][category][valueStr]++;
          }
        }
      }
    }

    return createSuccessResponse({ schedule: schedule, details: details });
  } catch (error) {
    return createErrorResponse('曜日別予定取得エラー: ' + error.message);
  }
}

/**
 * 利用者個人の統計を取得
 */
function handleGetUserStats(userName) {
  try {
    const supportSheet = getSheet(SHEET_NAMES.SUPPORT);

    // 当月の範囲を計算
    const now = new Date();
    const year = now.getFullYear();
    const month = now.getMonth() + 1;
    const firstDay = new Date(year, month - 1, 1);
    const lastDay = new Date(year, month, 0);

    const actualLastRow = findActualLastRow(supportSheet, SUPPORT_COLS.USER_NAME);

    let attendanceDays = 0;
    let absentDays = 0;
    let totalScheduled = 0;
    let totalWorkMinutes = 0;

    if (actualLastRow >= 2) {
      const MAX_SEARCH_ROWS = 1000;
      const searchRows = Math.min(actualLastRow - 1, MAX_SEARCH_ROWS);
      const startRow = Math.max(2, actualLastRow - searchRows + 1);

      // 日付、利用者名、出欠予定、出欠、実労時間を一括取得
      const dateData = supportSheet.getRange(startRow, SUPPORT_COLS.DATE, searchRows, 1).getValues();
      const nameData = supportSheet.getRange(startRow, SUPPORT_COLS.USER_NAME, searchRows, 1).getValues();
      const scheduledData = supportSheet.getRange(startRow, SUPPORT_COLS.SCHEDULED, searchRows, 1).getValues();
      const attendanceData = supportSheet.getRange(startRow, SUPPORT_COLS.ATTENDANCE, searchRows, 1).getValues();
      const workMinutesData = supportSheet.getRange(startRow, SUPPORT_COLS.WORK_MINUTES, searchRows, 1).getValues();

      for (let i = 0; i < searchRows; i++) {
        const dateVal = dateData[i][0];
        const rowUserName = nameData[i][0];

        if (!dateVal || !rowUserName) continue;
        if (rowUserName !== userName) continue;

        const rowDate = new Date(dateVal);
        // 当月のデータのみ集計
        if (rowDate >= firstDay && rowDate <= lastDay) {
          const scheduled = scheduledData[i][0];
          const attendance = attendanceData[i][0];
          const workMinutes = workMinutesData[i][0];

          // 出欠予定がある場合カウント
          if (scheduled && scheduled !== '') {
            totalScheduled++;
          }

          // 出欠状況で分類
          if (attendance === '出勤' || attendance === '遅刻') {
            attendanceDays++;
            if (workMinutes && typeof workMinutes === 'number') {
              totalWorkMinutes += workMinutes;
            }
          } else if (attendance === '欠勤') {
            absentDays++;
          }
        }
      }
    }

    // 統計を計算
    const attendanceRate = totalScheduled > 0 ? attendanceDays / totalScheduled : 0;
    const avgWorkMinutes = attendanceDays > 0 ? Math.round(totalWorkMinutes / attendanceDays) : 0;

    return createSuccessResponse({
      attendanceRate: attendanceRate,
      totalWorkMinutes: totalWorkMinutes,
      avgWorkMinutes: avgWorkMinutes,
      attendanceDays: attendanceDays,
      absentDays: absentDays
    });
  } catch (error) {
    return createErrorResponse('利用者統計取得エラー: ' + error.message);
  }
}

/**
 * 月別退所者一覧を取得
 * @param {string} [monthStr] - 対象月（YYYY-MM形式）。省略時は当月
 */
function handleGetDepartedUsers(monthStr) {
  try {
    const rosterSheet = getSheet(SHEET_NAMES.ROSTER);

    // 対象月の範囲を計算
    let year, month;
    if (monthStr && monthStr.match(/^\d{4}-\d{2}$/)) {
      const parts = monthStr.split('-');
      year = parseInt(parts[0], 10);
      month = parseInt(parts[1], 10);
    } else {
      const now = new Date();
      year = now.getFullYear();
      month = now.getMonth() + 1;
    }
    const firstDay = new Date(year, month - 1, 1);
    const lastDay = new Date(year, month, 0);

    const rosterLastRow = rosterSheet.getLastRow();
    if (rosterLastRow < 3) {
      return createSuccessResponse({ users: [], year: year, month: month });
    }

    const numRows = rosterLastRow - 2;

    // 名前(B列)、カナ(C列)、ステータス(E列)、退所日(BA列)、退所理由(BB列)を一括取得
    const nameData = rosterSheet.getRange(3, ROSTER_COLS.NAME, numRows, 1).getValues();
    const kanaData = rosterSheet.getRange(3, ROSTER_COLS.NAME_KANA, numRows, 1).getValues();
    const statusData = rosterSheet.getRange(3, ROSTER_COLS.STATUS, numRows, 1).getValues();
    const leaveDateData = rosterSheet.getRange(3, ROSTER_COLS.LEAVE_DATE, numRows, 1).getValues();
    const leaveReasonData = rosterSheet.getRange(3, ROSTER_COLS.LEAVE_REASON, numRows, 1).getValues();

    const departedUsers = [];

    for (let i = 0; i < numRows; i++) {
      const name = nameData[i][0];
      if (!name || name === '') continue;

      const status = statusData[i][0];
      const leaveDate = leaveDateData[i][0];

      // 退所済みで、退所日が対象月内の人をフィルタリング
      if (status === '退所済み' && leaveDate) {
        const leaveDateObj = new Date(leaveDate);
        if (leaveDateObj >= firstDay && leaveDateObj <= lastDay) {
          departedUsers.push({
            name: name,
            furigana: kanaData[i][0] || '',
            leaveDate: formatDate(leaveDate),
            leaveReason: leaveReasonData[i][0] || ''
          });
        }
      }
    }

    // 退所日順にソート（新しい順）
    departedUsers.sort((a, b) => {
      return new Date(b.leaveDate) - new Date(a.leaveDate);
    });

    return createSuccessResponse({
      users: departedUsers,
      year: year,
      month: month
    });
  } catch (error) {
    return createErrorResponse('退所者一覧取得エラー: ' + error.message);
  }
}

/**
 * 年度統計を取得
 * @param {number} [fiscalYear] - 年度（4月始まり）。省略時は当年度
 */
function handleGetYearlyStats(fiscalYear) {
  try {
    const supportSheet = getSheet(SHEET_NAMES.SUPPORT);
    const rosterSheet = getSheet(SHEET_NAMES.ROSTER);
    const masterSheet = getSheet(SHEET_NAMES.MASTER);

    // 年度の範囲を計算（4月〜翌3月）
    const now = new Date();
    if (!fiscalYear) {
      // 当年度を計算（1-3月は前年度）
      fiscalYear = now.getMonth() >= 3 ? now.getFullYear() : now.getFullYear() - 1;
    }
    const fiscalStart = new Date(fiscalYear, 3, 1);  // 4月1日
    const fiscalEnd = new Date(fiscalYear + 1, 2, 31, 23, 59, 59);  // 翌年3月31日

    // 月別統計を格納
    const monthlyData = {};
    for (let m = 4; m <= 12; m++) {
      monthlyData[`${fiscalYear}-${String(m).padStart(2, '0')}`] = {
        attendance: 0, scheduled: 0, workDays: new Set(),
        facilityHome: 0,  // 本施設 + 在宅 の実利用数
        external: 0       // 施設外 の実利用数
      };
    }
    for (let m = 1; m <= 3; m++) {
      monthlyData[`${fiscalYear + 1}-${String(m).padStart(2, '0')}`] = {
        attendance: 0, scheduled: 0, workDays: new Set(),
        facilityHome: 0,
        external: 0
      };
    }

    // 年度内の出勤データを集計
    const actualLastRow = findActualLastRow(supportSheet, SUPPORT_COLS.USER_NAME);
    let yearlyAttendance = 0;
    let yearlyScheduled = 0;
    const yearlyWorkDays = new Set();

    if (actualLastRow >= 2) {
      // 年度分のデータを検索（最大5000行）
      const MAX_SEARCH_ROWS = 5000;
      const searchRows = Math.min(actualLastRow - 1, MAX_SEARCH_ROWS);
      const startRow = Math.max(2, actualLastRow - searchRows + 1);

      // 日付、利用者名、出欠予定、出欠を一括取得
      const data = supportSheet.getRange(startRow, SUPPORT_COLS.DATE, searchRows, 4).getValues();

      for (let i = 0; i < data.length; i++) {
        const dateVal = data[i][0];
        if (!dateVal) continue;

        const rowDate = new Date(dateVal);
        // 年度内のデータのみ集計
        if (rowDate >= fiscalStart && rowDate <= fiscalEnd) {
          const userName = data[i][1];
          if (!userName || userName === '') continue;

          const scheduled = data[i][2];
          const attendance = data[i][3];

          // 月キーを作成
          const monthKey = `${rowDate.getFullYear()}-${String(rowDate.getMonth() + 1).padStart(2, '0')}`;

          // 出欠予定がある場合カウント
          if (scheduled && scheduled !== '') {
            yearlyScheduled++;
            if (monthlyData[monthKey]) {
              monthlyData[monthKey].scheduled++;
            }
          }

          // 出欠に何か入力があれば稼働日としてカウント
          if (attendance && attendance !== '') {
            const dateStr = formatDate(dateVal);
            yearlyWorkDays.add(dateStr);

            if (monthlyData[monthKey]) {
              monthlyData[monthKey].workDays.add(dateStr);
            }
          }

          // 出勤・在宅・施設外・遅刻・早退の場合、出勤延べ数としてカウント
          if (attendance === '出勤' || attendance === '在宅' || attendance === '施設外' || attendance === '遅刻' || attendance === '早退') {
            yearlyAttendance++;

            if (monthlyData[monthKey]) {
              monthlyData[monthKey].attendance++;

              // 種別ごとに実利用数をカウント（出欠の値で判定）
              if (attendance === '施設外') {
                monthlyData[monthKey].external++;
              } else {
                // 出勤、在宅、遅刻、早退は全て facilityHome としてカウント
                monthlyData[monthKey].facilityHome++;
              }
            }
          }
        }
      }
    }

    // 年度内の退所者数を集計
    let yearlyDeparted = 0;
    const rosterLastRow = rosterSheet.getLastRow();
    if (rosterLastRow >= 3) {
      const numRows = rosterLastRow - 2;
      const statusData = rosterSheet.getRange(3, ROSTER_COLS.STATUS, numRows, 1).getValues();
      const leaveDateData = rosterSheet.getRange(3, ROSTER_COLS.LEAVE_DATE, numRows, 1).getValues();

      for (let i = 0; i < numRows; i++) {
        const status = statusData[i][0];
        const leaveDate = leaveDateData[i][0];

        if (status === '退所済み' && leaveDate) {
          const leaveDateObj = new Date(leaveDate);
          if (leaveDateObj >= fiscalStart && leaveDateObj <= fiscalEnd) {
            yearlyDeparted++;
          }
        }
      }
    }

    // 出勤率を計算
    const attendanceRate = yearlyScheduled > 0 ? yearlyAttendance / yearlyScheduled : 0;

    // 月別サマリーを作成
    const monthlySummary = [];
    Object.keys(monthlyData).sort().forEach(key => {
      const data = monthlyData[key];
      const rate = data.scheduled > 0 ? data.attendance / data.scheduled : 0;
      monthlySummary.push({
        month: key,
        attendance: data.attendance,
        scheduled: data.scheduled,
        workDays: data.workDays.size,
        attendanceRate: rate,
        facilityHome: data.facilityHome,  // 本施設 + 在宅 の実利用数
        external: data.external           // 施設外 の実利用数
      });
    });

    // 直接支援員（生活支援員・職業指導員）の配置を雇用形態別に集計
    // 雇用形態: 常勤職員、非常勤職員（2日以下）、非常勤職員（3日以上）
    const directSupportByType = {
      fullTime: { facilityHome: 0, external: 0 },           // 常勤職員
      partTimeLess2: { facilityHome: 0, external: 0 },      // 非常勤職員（2日以下）
      partTimeMore3: { facilityHome: 0, external: 0 }       // 非常勤職員（3日以上）
    };

    // 福祉専門員等配置加算要件: 常勤の直接処遇職員の福祉資格保有率
    let fullTimeDirectSupportTotal = 0;      // 常勤の直接処遇職員数
    let fullTimeWithQualification = 0;       // うち福祉資格保有者数

    const staffStartRow = MASTER_CONFIG.STAFF_DATA_START_ROW;
    const staffLastRow = masterSheet.getLastRow();
    if (staffLastRow >= staffStartRow) {
      const numStaffRows = staffLastRow - staffStartRow + 1;
      const cols = MASTER_CONFIG.STAFF_COLS;
      // V列(22)からAD列(30)まで取得（退職日を含む）
      const staffData = masterSheet.getRange(staffStartRow, cols.NAME, numStaffRows, cols.RETIREMENT_DATE - cols.NAME + 1).getValues();

      for (let i = 0; i < staffData.length; i++) {
        const name = staffData[i][0];  // V列: 職員名
        if (!name || name === '') continue;

        const jobType = staffData[i][cols.JOB_TYPE - cols.NAME];  // Z列: 職種
        const qualification = staffData[i][cols.QUALIFICATION - cols.NAME];  // AA列: 保有福祉資格
        const placement = staffData[i][cols.PLACEMENT - cols.NAME];  // AB列: 職員配置
        const employmentType = staffData[i][cols.EMPLOYMENT_TYPE - cols.NAME];  // AC列: 雇用形態
        const retirementDate = staffData[i][cols.RETIREMENT_DATE - cols.NAME];  // AD列: 退職日

        // 退職日が入力されている場合はスキップ（統計から除外）
        if (retirementDate && retirementDate !== '') continue;

        // 直接支援員（生活支援員・職業指導員）のみ集計
        if (jobType === '生活支援員' || jobType === '職業指導員') {
          // 配置場所で分類（「本施設」を含む場合は本施設・在宅、それ以外は施設外）
          const isFacilityHome = placement && placement.includes('本施設');

          // 雇用形態で分類（「非常勤」も「常勤」を含むため、非常勤を先に判定）
          if (employmentType && (employmentType.includes('週2以下') || employmentType.includes('2日以下'))) {
            // 非常勤職員（週2以下）
            if (isFacilityHome) {
              directSupportByType.partTimeLess2.facilityHome++;
            } else {
              directSupportByType.partTimeLess2.external++;
            }
          } else if (employmentType && (employmentType.includes('週3以上') || employmentType.includes('3日以上'))) {
            // 非常勤職員（週3以上）
            if (isFacilityHome) {
              directSupportByType.partTimeMore3.facilityHome++;
            } else {
              directSupportByType.partTimeMore3.external++;
            }
          } else if (employmentType && employmentType.includes('常勤') && !employmentType.includes('非常勤')) {
            // 常勤職員（「非常勤」を含まないもののみ）
            if (isFacilityHome) {
              directSupportByType.fullTime.facilityHome++;
            } else {
              directSupportByType.fullTime.external++;
            }
            // 福祉専門員等配置加算要件: 常勤の直接処遇職員をカウント
            fullTimeDirectSupportTotal++;
            if (qualification && qualification !== '') {
              fullTimeWithQualification++;
            }
          }
        }
      }
    }

    // 合計も計算
    const totalFacilityHome = directSupportByType.fullTime.facilityHome +
                              directSupportByType.partTimeLess2.facilityHome +
                              directSupportByType.partTimeMore3.facilityHome;
    const totalExternal = directSupportByType.fullTime.external +
                          directSupportByType.partTimeLess2.external +
                          directSupportByType.partTimeMore3.external;

    // 福祉専門員等配置加算要件: 割合を計算
    const qualificationRate = fullTimeDirectSupportTotal > 0
      ? Math.round((fullTimeWithQualification / fullTimeDirectSupportTotal) * 100)
      : 0;

    return createSuccessResponse({
      fiscalYear: fiscalYear,
      fiscalYearLabel: `${fiscalYear}年度`,
      yearlyAttendance: yearlyAttendance,
      yearlyScheduled: yearlyScheduled,
      yearlyWorkDays: yearlyWorkDays.size,
      attendanceRate: attendanceRate,
      yearlyDeparted: yearlyDeparted,
      monthlySummary: monthlySummary,
      directSupportStaff: {
        facilityHome: totalFacilityHome,  // 本施設配置の直接支援員数（後方互換性）
        external: totalExternal,           // 施設外配置の直接支援員数（後方互換性）
        byEmploymentType: directSupportByType  // 雇用形態別の詳細
      },
      welfareQualification: {
        total: fullTimeDirectSupportTotal,           // 常勤の直接処遇職員数
        withQualification: fullTimeWithQualification, // うち福祉資格保有者数
        rate: qualificationRate                       // 福祉資格保有率（%）
      }
    });
  } catch (error) {
    return createErrorResponse('年度統計取得エラー: ' + error.message);
  }
}

/**
 * 分析データをバッチ取得（施設統計・退所者・曜日別予定を一括）
 * @param {string} monthStr - 月（YYYY-MM形式）
 */
function handleGetAnalyticsBatch(monthStr) {
  try {
    const masterSheet = getSheet(SHEET_NAMES.MASTER);
    const rosterSheet = getSheet(SHEET_NAMES.ROSTER);
    const supportSheet = getSheet(SHEET_NAMES.SUPPORT);

    // === 対象月の設定 ===
    let year, month;
    if (monthStr && monthStr.match(/^\d{4}-\d{2}$/)) {
      const parts = monthStr.split('-');
      year = parseInt(parts[0], 10);
      month = parseInt(parts[1], 10);
    } else {
      const now = new Date();
      year = now.getFullYear();
      month = now.getMonth() + 1;
    }
    const firstDay = new Date(year, month - 1, 1);
    const lastDay = new Date(year, month, 0);
    const now = new Date();
    const isCurrentMonth = (year === now.getFullYear() && month === now.getMonth() + 1);

    // === 名簿データを一括取得 ===
    const rosterLastRow = rosterSheet.getLastRow();
    let rosterData = [];
    if (rosterLastRow >= 3) {
      const numRows = rosterLastRow - 2;
      // 名前(B列)、ステータス(E列)、利用開始日(AH列)、退所日(BA列)、退所理由(BB列)を取得
      const nameData = rosterSheet.getRange(3, ROSTER_COLS.NAME, numRows, 1).getValues();
      const statusData = rosterSheet.getRange(3, ROSTER_COLS.STATUS, numRows, 1).getValues();
      const useStartDateData = rosterSheet.getRange(3, ROSTER_COLS.USE_START_DATE, numRows, 1).getValues();
      const leaveDateData = rosterSheet.getRange(3, ROSTER_COLS.LEAVE_DATE, numRows, 1).getValues();
      const leaveReasonData = rosterSheet.getRange(3, ROSTER_COLS.LEAVE_REASON, numRows, 1).getValues();

      for (let i = 0; i < numRows; i++) {
        if (nameData[i][0] && nameData[i][0] !== '') {
          rosterData.push({
            name: nameData[i][0],
            status: statusData[i][0],
            useStartDate: useStartDateData[i][0],
            leaveDate: leaveDateData[i][0],
            leaveReason: leaveReasonData[i][0]
          });
        }
      }
    }

    // === 1. 施設統計（facilityStats） ===
    const contractedUsersList = [];
    const departedUsers = [];
    const futureDepatedUsersList = [];

    // 日付パース共通関数（YYYYMMDD形式/日付型両対応）
    const parseDate = (rawDate) => {
      if (!rawDate) return null;
      const rawStr = String(rawDate);
      if (rawStr.match(/^\d{8}$/)) {
        return new Date(
          parseInt(rawStr.substring(0, 4), 10),
          parseInt(rawStr.substring(4, 6), 10) - 1,
          parseInt(rawStr.substring(6, 8), 10)
        );
      }
      const d = new Date(rawDate);
      return (!isNaN(d.getTime()) && d.getFullYear() >= 2000) ? d : null;
    };

    for (const user of rosterData) {
      const status = (user.status || '').toString().trim();

      // 利用開始日チェック（対象月の翌月以降に開始 → スキップ）
      const startDate = parseDate(user.useStartDate);
      if (startDate && startDate > lastDay) continue;

      if (status === '契約中') {
        contractedUsersList.push(user.name);
      } else if (status === '退所済み') {
        const leaveDate = parseDate(user.leaveDate);
        if (!leaveDate) continue;

        if (leaveDate >= firstDay && leaveDate <= lastDay) {
          // 当月退所 → 「退所」マーク付き
          departedUsers.push({
            userName: user.name,
            leaveDate: formatDate(leaveDate),
            leaveReason: user.leaveReason || ''
          });
        } else if (leaveDate > lastDay) {
          // 後に退所（この月は在籍中）
          futureDepatedUsersList.push(user.name);
        }
      }
    }

    const totalUsers = contractedUsersList.length + departedUsers.length + futureDepatedUsersList.length;

    // 出勤データを集計（当月＋前月）
    const actualLastRow = findActualLastRow(supportSheet, SUPPORT_COLS.USER_NAME);
    let monthlyAttendance = 0;
    let totalScheduled = 0;
    const workDays = new Set();

    // 前月の範囲
    const prevMonth = month === 1 ? 12 : month - 1;
    const prevYear = month === 1 ? year - 1 : year;
    const prevFirstDay = new Date(prevYear, prevMonth - 1, 1);
    const prevLastDay = new Date(prevYear, prevMonth, 0);
    let prevMonthlyAttendance = 0;
    const prevWorkDays = new Set();

    if (actualLastRow >= 2) {
      const MAX_SEARCH_ROWS = isCurrentMonth ? 1500 : 3500;  // 前月も含めるため増加
      const searchRows = Math.min(actualLastRow - 1, MAX_SEARCH_ROWS);
      const startRow = Math.max(2, actualLastRow - searchRows + 1);

      const data = supportSheet.getRange(startRow, SUPPORT_COLS.DATE, searchRows, 4).getValues();

      for (let i = 0; i < data.length; i++) {
        const dateVal = data[i][0];
        if (!dateVal) continue;

        const rowDate = new Date(dateVal);
        const userName = data[i][1];
        if (!userName || userName === '') continue;

        const scheduled = data[i][2];
        const attendance = data[i][3];

        // 当月のデータ
        if (rowDate >= firstDay && rowDate <= lastDay) {
          if (scheduled && scheduled !== '') {
            totalScheduled++;
          }
          // 出欠に何か入力があれば稼働日としてカウント
          if (attendance && attendance !== '') {
            workDays.add(formatDate(dateVal));
          }
          // 出勤・在宅・施設外・遅刻・早退の場合、出勤延べ数としてカウント
          if (attendance === '出勤' || attendance === '在宅' || attendance === '施設外' || attendance === '遅刻' || attendance === '早退') {
            monthlyAttendance++;
          }
        }

        // 前月のデータ
        if (rowDate >= prevFirstDay && rowDate <= prevLastDay) {
          // 出欠に何か入力があれば稼働日としてカウント
          if (attendance && attendance !== '') {
            prevWorkDays.add(formatDate(dateVal));
          }
          // 出勤・在宅・施設外・遅刻・早退の場合、出勤延べ数としてカウント
          if (attendance === '出勤' || attendance === '在宅' || attendance === '施設外' || attendance === '遅刻' || attendance === '早退') {
            prevMonthlyAttendance++;
          }
        }
      }
    }

    const attendanceRate = totalScheduled > 0 ? monthlyAttendance / totalScheduled : 0;

    // 1日あたりの平均利用人数
    const avgUsersPerDay = workDays.size > 0 ? monthlyAttendance / workDays.size : 0;
    const prevAvgUsersPerDay = prevWorkDays.size > 0 ? prevMonthlyAttendance / prevWorkDays.size : 0;
    const avgUsersChange = avgUsersPerDay - prevAvgUsersPerDay;

    // === 2. 曜日別予定（weeklySchedule） ===
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    const schedule = {};
    const details = {};
    weekdays.forEach(day => {
      schedule[day] = { '本施設': 0, '施設外': 0, '在宅': 0 };
      details[day] = { '本施設': {}, '施設外': {}, '在宅': {} };
    });

    const weekdayMap = {
      4: '月', // D列
      5: '火', // E列
      6: '水', // F列
      7: '木', // G列
      8: '金', // H列
      9: '土', // I列
      10: '日' // J列
    };

    const masterLastRow = masterSheet.getLastRow();
    if (masterLastRow >= MASTER_CONFIG.USER_DATA_START_ROW) {
      const startRow = MASTER_CONFIG.USER_DATA_START_ROW;
      const numRows = masterLastRow - startRow + 1;

      // 名前(A列)、ステータス(C列)、曜日別予定(D-J列)を一括取得
      const masterData = masterSheet.getRange(startRow, 1, numRows, 10).getValues();

      for (let i = 0; i < masterData.length; i++) {
        const name = masterData[i][0];
        if (!name || name === '') break;

        const status = masterData[i][2]; // C列: ステータス
        if (status !== '契約中') continue;

        // D列〜J列（曜日別予定）をチェック
        for (let col = 3; col <= 9; col++) { // 配列インデックス3-9 = D-J列
          const value = masterData[i][col];
          if (!value || value === '') continue;

          const weekday = weekdayMap[col + 1]; // 配列インデックス+1 = 列番号
          const valueStr = String(value).trim();

          // 「非利用日」は除外
          if (valueStr.includes('非利用') || valueStr === '非利用日') continue;

          // 値に基づいて分類
          let category = '';
          if (valueStr.includes('施設外') || valueStr.includes('外')) {
            category = '施設外';
          } else if (valueStr.includes('在宅') || valueStr.includes('自宅')) {
            category = '在宅';
          } else if (valueStr !== '') {
            category = '本施設';
          }

          if (category) {
            schedule[weekday][category]++;
            // 詳細データに元の値をカウント
            if (!details[weekday][category][valueStr]) {
              details[weekday][category][valueStr] = 0;
            }
            details[weekday][category][valueStr]++;
          }
        }
      }
    }

    // 利用者名リストを結合（契約中 + 後に退所 + 当月退所者）※名簿シートの順番を維持
    const activeUsersList = [
      ...contractedUsersList,
      ...futureDepatedUsersList,  // 対象月より後に退所した人（その月は在籍中だった）
      ...departedUsers.map(u => u.userName + '（退所）')  // 当月退所者は「退所」マーク付き
    ];

    return createSuccessResponse({
      // 施設統計
      facilityStats: {
        year: year,
        month: month,
        totalUsers: totalUsers,
        activeUsersList: activeUsersList,  // 利用者名一覧
        attendanceRate: attendanceRate,
        monthlyWorkDays: workDays.size,
        monthlyAttendance: monthlyAttendance,
        avgUsersPerDay: Math.round(avgUsersPerDay * 10) / 10,  // 小数点1桁
        prevAvgUsersPerDay: Math.round(prevAvgUsersPerDay * 10) / 10,
        avgUsersChange: Math.round(avgUsersChange * 10) / 10
      },
      // 退所者一覧
      departedUsers: departedUsers,
      // 曜日別予定
      weeklySchedule: {
        schedule: schedule,
        details: details
      }
    });
  } catch (error) {
    return createErrorResponse('バッチ分析取得エラー: ' + error.message);
  }
}

// === 年度管理機能 ===

/**
 * 利用可能な年度一覧を取得（施設フォルダ内のスプレッドシートを検索）
 */
function handleGetAvailableFiscalYears() {
  try {
    const currentSs = SpreadsheetApp.getActiveSpreadsheet();
    const currentSsId = currentSs.getId();
    const currentSsName = currentSs.getName();

    // 施設IDをファイル名から抽出
    const facilityIdMatch = currentSsName.match(/^(\d+)_/);
    const facilityId = facilityIdMatch ? facilityIdMatch[1] : null;

    // 親フォルダを取得
    const currentFile = DriveApp.getFileById(currentSsId);
    const parentFolders = currentFile.getParents();

    const yearSpreadsheets = [];

    if (parentFolders.hasNext() && facilityId) {
      const parentFolder = parentFolders.next();

      // フォルダ内のスプレッドシートを検索
      const files = parentFolder.getFilesByType(MimeType.GOOGLE_SHEETS);

      while (files.hasNext()) {
        const file = files.next();
        const fileName = file.getName();

        // ファイル名パターン: {施設ID}_マスタ設定_{年度}
        const match = fileName.match(new RegExp(`^${facilityId}_マスタ設定_(\\d{4})$`));
        if (match) {
          const year = parseInt(match[1], 10);
          yearSpreadsheets.push({
            year: year,
            spreadsheetId: file.getId(),
            name: fileName,
            url: `https://docs.google.com/spreadsheets/d/${file.getId()}/edit`
          });
        }
      }
    }

    // 年度で降順ソート
    yearSpreadsheets.sort((a, b) => b.year - a.year);

    // 現在の年度を取得（4月始まりの場合）
    const now = new Date();
    const currentMonth = now.getMonth() + 1;
    const currentYear = now.getFullYear();
    const currentFiscalYear = currentMonth >= 4 ? currentYear : currentYear - 1;

    // 現在のスプレッドシートの年度を取得
    const currentSsYearMatch = currentSsName.match(/_(\d{4})$/);
    const activeYear = currentSsYearMatch ? parseInt(currentSsYearMatch[1], 10) : DEFAULT_FISCAL_YEAR;

    return createSuccessResponse({
      availableYears: yearSpreadsheets.map(s => s.year),
      yearSpreadsheets: yearSpreadsheets,
      currentFiscalYear: currentFiscalYear,
      activeYear: activeYear,
      defaultYear: DEFAULT_FISCAL_YEAR
    });
  } catch (error) {
    return createErrorResponse('年度一覧取得エラー: ' + error.message);
  }
}

/**
 * 次年度スプレッドシートを新規ファイルとして作成し、契約中利用者をコピー
 */
function handleCreateNextFiscalYear(data) {
  try {
    const currentYear = data.currentYear || DEFAULT_FISCAL_YEAR;
    const nextYear = currentYear + 1;

    // 現在のスプレッドシート情報を取得
    const currentSs = SpreadsheetApp.getActiveSpreadsheet();
    const currentSsId = currentSs.getId();
    const currentSsName = currentSs.getName();

    // 施設IDをファイル名から抽出（例: "222222_マスタ設定_2025" → "222222"）
    const facilityIdMatch = currentSsName.match(/^(\d+)_/);
    const facilityId = facilityIdMatch ? facilityIdMatch[1] : 'unknown';

    // 新しいファイル名
    const newFileName = `${facilityId}_マスタ設定_${nextYear}`;

    // 親フォルダを取得
    const currentFile = DriveApp.getFileById(currentSsId);
    const parentFolders = currentFile.getParents();

    if (!parentFolders.hasNext()) {
      return createErrorResponse('施設フォルダが見つかりません');
    }

    const parentFolder = parentFolders.next();

    // 同じ名前のファイルが既に存在するかチェック
    const existingFiles = parentFolder.getFilesByName(newFileName);
    if (existingFiles.hasNext()) {
      return createErrorResponse(`${nextYear}年度のスプレッドシートは既に存在します`);
    }

    // 現在のスプレッドシートをコピーして新しいファイルを作成
    const newFile = currentFile.makeCopy(newFileName, parentFolder);
    const newSs = SpreadsheetApp.openById(newFile.getId());

    // 新しいスプレッドシートのシート名を更新
    const sheetsToRename = [
      { oldPattern: `支援記録_${currentYear}`, newName: `支援記録_${nextYear}` },
      { oldPattern: `名簿_${currentYear}`, newName: `名簿_${nextYear}` }
    ];

    sheetsToRename.forEach(({ oldPattern, newName }) => {
      const sheet = newSs.getSheetByName(oldPattern);
      if (sheet) {
        sheet.setName(newName);
      }
    });

    // 支援記録シートのデータをクリア（A列にデータがある行を削除）
    // 支援記録シートは1行目がヘッダー、2行目以降がデータ
    const SUPPORT_DATA_START_ROW = 2;
    const currentSupportSheet = currentSs.getSheetByName(`支援記録_${currentYear}`);

    if (currentSupportSheet) {
      const lastRow = currentSupportSheet.getLastRow();

      if (lastRow >= SUPPORT_DATA_START_ROW) {
        // A列のデータを取得（2行目以降）
        const numRows = lastRow - SUPPORT_DATA_START_ROW + 1;
        const colAData = currentSupportSheet.getRange(SUPPORT_DATA_START_ROW, 1, numRows, 1).getValues();

        // A列にデータがある行数をカウント
        let dataRowCount = 0;
        for (let i = 0; i < colAData.length; i++) {
          if (colAData[i][0] !== '' && colAData[i][0] !== null) {
            dataRowCount++;
          }
        }

        // 新しいスプレッドシートの支援記録シートからデータ行を削除
        const newSupportSheet = newSs.getSheetByName(`支援記録_${nextYear}`);
        if (newSupportSheet && dataRowCount > 0) {
          newSupportSheet.deleteRows(SUPPORT_DATA_START_ROW, dataRowCount);
        }
      }
    }

    // 変更を強制保存
    SpreadsheetApp.flush();

    // マスタ設定シートの処理（契約中の利用者のみA〜J列に詰めて保持）
    const newMasterSheet = newSs.getSheetByName(FIXED_SHEET_NAMES.MASTER);
    if (newMasterSheet) {
      const masterStartRow = MASTER_CONFIG.USER_DATA_START_ROW; // 8行目から
      const masterLastRow = newMasterSheet.getLastRow();

      if (masterLastRow >= masterStartRow) {
        // A〜J列のデータを取得（利用者情報範囲）
        const masterNumRows = masterLastRow - masterStartRow + 1;
        const masterData = newMasterSheet.getRange(masterStartRow, 1, masterNumRows, 10).getValues(); // A〜J列

        // 契約中の利用者のみ抽出
        const contractedUserData = [];
        for (let i = 0; i < masterData.length; i++) {
          const name = masterData[i][0]; // A列（名前）
          const status = masterData[i][2]; // C列（契約状態）

          // 名前があり、契約中の利用者のみ保持
          if (name && name !== '' && status === '契約中') {
            contractedUserData.push(masterData[i]);
          }
        }

        // A〜J列のデータを全てクリア
        newMasterSheet.getRange(masterStartRow, 1, masterNumRows, 10).clearContent();

        // 契約中の利用者データを8行目から詰めて書き込み
        if (contractedUserData.length > 0) {
          newMasterSheet.getRange(masterStartRow, 1, contractedUserData.length, 10)
            .setValues(contractedUserData);
        }
      }
    }

    // 変更を強制保存
    SpreadsheetApp.flush();

    // 名簿シートの処理
    const newRosterSheet = newSs.getSheetByName(`名簿_${nextYear}`);
    const currentRosterSheet = currentSs.getSheetByName(`名簿_${currentYear}`);
    let copiedUsers = 0;

    if (newRosterSheet && currentRosterSheet) {
      // 名簿の8行目以降のデータをクリア（書式・罫線は保持）
      const rosterLastRow = newRosterSheet.getLastRow();
      const rosterLastCol = newRosterSheet.getLastColumn();
      if (rosterLastRow > 7 && rosterLastCol > 0) {
        newRosterSheet.getRange(8, 1, rosterLastRow - 7, rosterLastCol).clearContent();
      }

      // 契約中の利用者を新しい名簿シートにコピー
      copiedUsers = copyContractedUsersToNewRoster(
        currentRosterSheet,
        newRosterSheet
      );
    }

    // 新しいスプレッドシートのURLとIDを返す
    const newSsUrl = newSs.getUrl();
    const newSsId = newSs.getId();

    return createSuccessResponse({
      message: `${nextYear}年度のスプレッドシートを作成しました`,
      nextYear: nextYear,
      copiedUsersCount: copiedUsers,
      newSpreadsheet: {
        id: newSsId,
        name: newFileName,
        url: newSsUrl
      }
    });
  } catch (error) {
    return createErrorResponse('次年度シート作成エラー: ' + error.message);
  }
}

/**
 * 契約中の利用者を新しい名簿シートにコピー
 */
function copyContractedUsersToNewRoster(sourceSheet, targetSheet) {
  const cols = ROSTER_COLS;
  const startRow = 8; // データ開始行
  const lastRow = sourceSheet.getLastRow();

  if (lastRow < startRow) {
    return 0; // データなし
  }

  // 全データを一括取得
  const numRows = lastRow - startRow + 1;
  const numCols = 60; // A〜BH列（60列）
  const allData = sourceSheet.getRange(startRow, 1, numRows, numCols).getValues();

  // 契約中の利用者のみ抽出
  const contractedUsers = [];
  for (let i = 0; i < allData.length; i++) {
    const row = allData[i];
    const name = row[cols.NAME - 1]; // B列（0-indexed: 1）
    const status = row[cols.STATUS - 1]; // E列（0-indexed: 4）

    // 空行または退所済みはスキップ
    if (!name || name === '') continue;
    if (status !== '契約中') continue;

    // コピーするデータを準備（退所関連情報はクリア）
    const newRow = [...row];

    // 退所・就労情報（AZ〜BH列）をクリア
    newRow[cols.LEAVE_DATE - 1] = ''; // BA列: 退所日
    newRow[cols.LEAVE_REASON - 1] = ''; // BB列: 退所理由
    newRow[cols.WORK_NAME - 1] = ''; // BC列: 勤務先
    newRow[cols.WORK_CONTACT - 1] = ''; // BD列: 勤務先連絡先
    newRow[cols.WORK_CONTENT - 1] = ''; // BE列: 業務内容
    newRow[cols.CONTRACT_TYPE - 1] = ''; // BF列: 契約形態
    newRow[cols.EMPLOYMENT_SUPPORT - 1] = ''; // BG列: 定着支援

    // 自動計算列もクリア（新年度で再計算）
    newRow[cols.USE_PERIOD - 1] = ''; // AI列: 利用期間
    newRow[cols.INITIAL_ADDITION - 1] = ''; // AJ列: 初期加算

    contractedUsers.push(newRow);
  }

  // 契約中利用者を新シートに一括書き込み
  if (contractedUsers.length > 0) {
    targetSheet.getRange(startRow, 1, contractedUsers.length, numCols)
      .setValues(contractedUsers);
  }

  return contractedUsers.length;
}

// === 請求業務機能 ===

/**
 * 請求業務用プルダウン選択肢を取得
 * マスタ設定シートのK61:P90から選択肢を取得
 */
function handleGetBillingDropdowns() {
  try {
    const sheet = getSheet(FIXED_SHEET_NAMES.MASTER);

    // プルダウン設定の範囲（60行目がヘッダー、61〜90行目がデータ）
    const BILLING_DROPDOWN_START_ROW = 61;
    const BILLING_DROPDOWN_END_ROW = 90;
    const numRows = BILLING_DROPDOWN_END_ROW - BILLING_DROPDOWN_START_ROW + 1;

    // 列定義（K〜P列）
    const BILLING_DROPDOWN_COLS = {
      TYPE: 11,                    // K列：種別
      WAGE_CATEGORY: 12,           // L列：平均工賃月額区分
      REGION_CATEGORY: 13,         // M列：地域区分
      WELFARE_STAFF_ADDITION: 14,  // N列：福祉専門職員配置等加算
      TRANSPORT_ADDITION: 15,      // O列：送迎加算種類
      WELFARE_IMPROVEMENT: 16      // P列：福祉介護職員等処遇改善加算
    };

    // K〜P列のデータを一括取得（6列分）
    const data = sheet.getRange(
      BILLING_DROPDOWN_START_ROW,
      BILLING_DROPDOWN_COLS.TYPE,
      numRows,
      6  // K〜P列（6列）
    ).getValues();

    // 各列の選択肢を抽出（空でない値のみ）
    const extractOptions = (colIndex) => {
      const options = [];
      for (let i = 0; i < data.length; i++) {
        const value = data[i][colIndex];
        if (value !== '' && value !== null && value !== undefined) {
          options.push(String(value));
        }
      }
      return options;
    };

    const dropdowns = {
      // K列：種別
      type: extractOptions(0),
      // L列：平均工賃月額区分
      wageCategory: extractOptions(1),
      // M列：地域区分
      regionCategory: extractOptions(2),
      // N列：福祉専門職員配置等加算
      welfareStaffAddition: extractOptions(3),
      // O列：送迎加算種類
      transportAddition: extractOptions(4),
      // P列：福祉介護職員等処遇改善加算
      welfareImprovement: extractOptions(5)
    };

    return createSuccessResponse(dropdowns);
  } catch (error) {
    return createErrorResponse('請求業務プルダウン取得エラー: ' + error.message);
  }
}

/**
 * 請求業務設定を保存
 * 請求タブのB列（3行目〜51行目）に保存
 */
function handleSaveBillingSettings(data) {
  try {
    const settings = data.settings;
    if (!settings) {
      return createErrorResponse('設定データがありません');
    }

    // 請求シートを取得（年度付き）
    const fiscalYear = data.fiscalYear || DEFAULT_FISCAL_YEAR;
    const billingSheetName = `請求_${fiscalYear}`;
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    let sheet = ss.getSheetByName(billingSheetName);

    if (!sheet) {
      return createErrorResponse(`請求シート（${billingSheetName}）が見つかりません`);
    }

    // Unicode定数: ○ = U+25CB (WHITE CIRCLE), ● = U+25CF (BLACK CIRCLE)
    const CIRCLE = '\u25CB';

    // B列の3行目から51行目に一括書き込み
    const values = [
      [settings.serviceYearMonth || ''],      // B3: サービス提供年月
      [settings.corporateName || ''],          // B4: 法人名
      [settings.representative || ''],         // B5: 代表者
      [settings.businessName || ''],           // B6: 事業者名
      [settings.abbreviation || ''],           // B7: 略称
      [settings.manager || ''],                // B8: 管理者
      [settings.businessNumber || ''],         // B9: 事業者番号
      [settings.postalCode || ''],             // B10: 郵便番号
      [settings.address || ''],                // B11: 住所
      [settings.phone || ''],                  // B12: 電話番号
      [settings.type || ''],                   // B13: 種別
      [settings.wageCategory || ''],           // B14: 平均工賃月額区分
      [settings.isPublic ? CIRCLE : ''],       // B15: 公立
      [settings.regionCategory || ''],         // B16: 地域区分
      [settings.capacity || ''],               // B17: 定員
      [settings.typeCapacity || ''],           // B18: 種類別定員
      [settings.standardUnit || ''],           // B19: 基準該当算定単位数
      [settings.hasTransitionSupport ? CIRCLE : ''],  // B20: 就労移行支援体制加算
      [settings.transitionWorkers || ''],      // B21: 就労定着者数
      [settings.welfareStaffAddition || ''],   // B22: 福祉専門職員配置等加算
      [settings.severeSupport || ''],          // B23: 重度者支援体制加算
      [settings.targetWageInstructor || ''],   // B24: 目標工賃達成指導員配置加算
      [settings.hasTargetWageAchievement ? CIRCLE : ''],  // B25: 目標工賃達成加算
      [settings.severeSupport2 || ''],         // B26: 重度者支援体制加算２
      [settings.medicalCooperation || ''],     // B27: 医療連携看護職員
      [settings.transportAddition || ''],      // B28: 送迎加算種類
      [settings.hasRestraintReduction ? CIRCLE : ''],  // B29: 身体拘束廃止未実施減算
      [settings.hasRegionalLifeSupport ? CIRCLE : ''],  // B30: 地域生活支援拠点等
      [settings.overCapacity || ''],           // B31: 定員超過
      [settings.employeeShortage || ''],       // B32: 従業員欠員
      [settings.serviceManagerShortage || ''], // B33: サービス管理責任者欠員
      [settings.hasShortTimeReduction ? CIRCLE : ''],  // B34: 短時間利用減算
      [settings.hasInfoDisclosureReduction ? CIRCLE : ''],  // B35: 情報公表未報告減算
      [settings.hasBcpReduction ? CIRCLE : ''],   // B36: 業務継続計画未策定減算
      [settings.hasAbusePreventionReduction ? CIRCLE : ''],  // B37: 虐待防止措置未実施減算
      [settings.visualHearingSpeechSupport || ''],  // B38: 視覚聴覚言語障害者支援体制加算
      [settings.hasHigherBrainSupport ? CIRCLE : ''],  // B39: 高次脳機能障害者支援体制加算
      [''],  // B40: 処遇改善都道府県（自動計算）
      [''],  // B41: 処遇改善都道府県番号（自動計算）
      [''],  // B42: 処遇改善キャリアパス区分（自動計算）
      [''],  // B43: 特定処遇改善加算（自動計算）
      [''],  // B44: ベースアップ等支援加算（自動計算）
      [settings.welfareImprovement || ''],     // B45: 福祉介護職員等処遇改善加算
      [settings.isDesignatedFacility ? CIRCLE : ''],  // B46: 指定障害者支援施設
      [settings.invoicePosition || ''],        // B47: 請求書役職
      [settings.invoiceName || ''],            // B48: 請求書氏名
      [settings.invoiceNote || ''],            // B49: 利用者請求書備考
      [settings.expense1 || ''],               // B50: 実費１
      [settings.expense2 || '']                // B51: 実費２
    ];

    // B3:B51に一括書き込み（49行）
    sheet.getRange(3, 2, values.length, 1).setValues(values);

    return createSuccessResponse({ message: '請求業務設定を保存しました' });
  } catch (error) {
    return createErrorResponse('請求業務設定保存エラー: ' + error.message);
  }
}

/**
 * 請求業務設定を取得
 * 請求タブのB列（3行目〜51行目）から取得
 */
function handleGetBillingSettings() {
  try {
    // 請求シートを取得（年度付き）
    const fiscalYear = DEFAULT_FISCAL_YEAR;
    const billingSheetName = `請求_${fiscalYear}`;
    const ss = SpreadsheetApp.getActiveSpreadsheet();
    let sheet = ss.getSheetByName(billingSheetName);

    if (!sheet) {
      return createErrorResponse(`請求シート（${billingSheetName}）が見つかりません`);
    }

    // Unicode定数: ○ = U+25CB (WHITE CIRCLE)
    const CIRCLE = '\u25CB';

    // B3:B51を一括取得（49行）
    const values = sheet.getRange(3, 2, 49, 1).getValues();

    const settings = {
      serviceYearMonth: values[0][0] || '',      // B3
      corporateName: values[1][0] || '',          // B4
      representative: values[2][0] || '',         // B5
      businessName: values[3][0] || '',           // B6
      abbreviation: values[4][0] || '',           // B7
      manager: values[5][0] || '',                // B8
      businessNumber: values[6][0] || '',         // B9
      postalCode: values[7][0] || '',             // B10
      address: values[8][0] || '',                // B11
      phone: values[9][0] || '',                  // B12
      type: values[10][0] || '',                  // B13
      wageCategory: values[11][0] || '',          // B14
      isPublic: values[12][0] === CIRCLE,         // B15
      regionCategory: values[13][0] || '',        // B16
      capacity: values[14][0] || '',              // B17
      typeCapacity: values[15][0] || '',          // B18
      standardUnit: values[16][0] || '',          // B19
      hasTransitionSupport: values[17][0] === CIRCLE, // B20
      transitionWorkers: values[18][0] || '',     // B21
      welfareStaffAddition: values[19][0] || '',  // B22
      severeSupport: values[20][0] || '',         // B23
      targetWageInstructor: values[21][0] || '',  // B24
      hasTargetWageAchievement: values[22][0] === CIRCLE, // B25
      severeSupport2: values[23][0] || '',        // B26
      medicalCooperation: values[24][0] || '',    // B27
      transportAddition: values[25][0] || '',     // B28
      hasRestraintReduction: values[26][0] === CIRCLE, // B29
      hasRegionalLifeSupport: values[27][0] === CIRCLE, // B30
      overCapacity: values[28][0] || '',          // B31
      employeeShortage: values[29][0] || '',      // B32
      serviceManagerShortage: values[30][0] || '', // B33
      hasShortTimeReduction: values[31][0] === CIRCLE, // B34
      hasInfoDisclosureReduction: values[32][0] === CIRCLE, // B35
      hasBcpReduction: values[33][0] === CIRCLE,  // B36
      hasAbusePreventionReduction: values[34][0] === CIRCLE, // B37
      visualHearingSpeechSupport: values[35][0] || '', // B38
      hasHigherBrainSupport: values[36][0] === CIRCLE, // B39
      // B40-B44は自動計算のためスキップ
      welfareImprovement: values[42][0] || '',    // B45
      isDesignatedFacility: values[43][0] === CIRCLE, // B46
      invoicePosition: values[44][0] || '',       // B47
      invoiceName: values[45][0] || '',           // B48
      invoiceNote: values[46][0] || '',           // B49
      expense1: values[47][0] || '',              // B50
      expense2: values[48][0] || ''               // B51
    };

    return createSuccessResponse(settings);
  } catch (error) {
    return createErrorResponse('請求業務設定取得エラー: ' + error.message);
  }
}

/**
 * 指定月の利用者一覧を取得（統計・分析と同じロジック）
 * 名簿シートから取得し、利用開始日・退所日を考慮
 */
function handleGetMonthlyUsers(data) {
  try {
    const rosterSheet = getSheet(SHEET_NAMES.ROSTER);
    const yearMonth = data.yearMonth || '';

    // 対象月の範囲を計算
    let year, month;
    if (yearMonth && yearMonth.match(/^\d{4}-\d{2}$/)) {
      [year, month] = yearMonth.split('-').map(Number);
    } else {
      const now = new Date();
      year = now.getFullYear();
      month = now.getMonth() + 1;
    }
    const firstDay = new Date(year, month - 1, 1);
    const lastDay = new Date(year, month, 0);

    // 名簿シートからデータを一括取得
    const rosterLastRow = rosterSheet.getLastRow();
    if (rosterLastRow < 3) {
      return createSuccessResponse({ users: [] });
    }

    const numRows = rosterLastRow - 2;
    const nameData = rosterSheet.getRange(3, ROSTER_COLS.NAME, numRows, 1).getValues();
    const kanaData = rosterSheet.getRange(3, ROSTER_COLS.NAME_KANA, numRows, 1).getValues();
    const statusData = rosterSheet.getRange(3, ROSTER_COLS.STATUS, numRows, 1).getValues();
    const useStartDateData = rosterSheet.getRange(3, ROSTER_COLS.USE_START_DATE, numRows, 1).getValues();
    const leaveDateData = rosterSheet.getRange(3, ROSTER_COLS.LEAVE_DATE, numRows, 1).getValues();

    // 日付パース共通関数
    const parseDate = (rawDate) => {
      if (!rawDate) return null;
      const rawStr = String(rawDate);
      if (rawStr.match(/^\d{8}$/)) {
        return new Date(
          parseInt(rawStr.substring(0, 4), 10),
          parseInt(rawStr.substring(4, 6), 10) - 1,
          parseInt(rawStr.substring(6, 8), 10)
        );
      }
      const d = new Date(rawDate);
      return (!isNaN(d.getTime()) && d.getFullYear() >= 2000) ? d : null;
    };

    const users = [];

    for (let i = 0; i < numRows; i++) {
      const name = nameData[i][0];
      if (!name || name === '') continue;

      const furigana = kanaData[i][0] || '';
      const status = (statusData[i][0] || '').toString().trim();

      // 利用開始日チェック（対象月の翌月以降に開始 → スキップ）
      const startDate = parseDate(useStartDateData[i][0]);
      if (startDate && startDate > lastDay) continue;

      if (status === '契約中') {
        users.push({ name, furigana, isDeparted: false });
      } else if (status === '退所済み') {
        const leaveDate = parseDate(leaveDateData[i][0]);
        if (!leaveDate) continue;

        if (leaveDate >= firstDay) {
          // 退所日が対象月以降 → この月は在籍中だった
          const isDepartedThisMonth = leaveDate <= lastDay;
          users.push({ name, furigana, isDeparted: isDepartedThisMonth });
        }
        // 退所日 < firstDay → 退所月の翌月以降なのでスキップ
      }
    }

    return createSuccessResponse({ users });
  } catch (error) {
    return createErrorResponse('利用者取得エラー: ' + error.message);
  }
}

// === 市町村情報管理 ===

/**
 * 市町村一覧を取得
 * マスタ設定シートのQ61:R列以降から取得
 */
function handleGetMunicipalities() {
  try {
    const sheet = getSheet(SHEET_NAMES.MASTER);
    const startRow = 61;
    const maxRows = 50; // 最大50件まで

    // Q列（市町村名）とR列（市町村番号）を一括取得
    const data = sheet.getRange(startRow, 17, maxRows, 2).getValues();

    const municipalities = [];
    for (let i = 0; i < data.length; i++) {
      const name = data[i][0];
      const code = data[i][1];

      // 空行で終了
      if (!name && !code) {
        break;
      }

      municipalities.push({
        name: name || '',
        code: code ? String(code) : ''
      });
    }

    return createSuccessResponse({ municipalities: municipalities });
  } catch (error) {
    return createErrorResponse('市町村一覧取得エラー: ' + error.message);
  }
}

/**
 * 市町村を追加
 * マスタ設定シートのQ61:R列の次の空行に追加
 */
function handleAddMunicipality(data) {
  try {
    const name = data.name;
    const code = data.code;

    if (!name) {
      return createErrorResponse('市町村名は必須です');
    }

    const sheet = getSheet(SHEET_NAMES.MASTER);
    const startRow = 61;
    const maxRows = 50;

    // 現在のデータを取得して次の空行を探す
    const existing = sheet.getRange(startRow, 17, maxRows, 1).getValues();
    let nextRow = startRow;

    for (let i = 0; i < existing.length; i++) {
      if (!existing[i][0]) {
        nextRow = startRow + i;
        break;
      }
      if (i === existing.length - 1) {
        return createErrorResponse('登録可能な市町村数の上限に達しました');
      }
    }

    // データを書き込み
    sheet.getRange(nextRow, 17).setValue(name);
    sheet.getRange(nextRow, 18).setValue(code || '');

    return createSuccessResponse({ message: '市町村を追加しました' });
  } catch (error) {
    return createErrorResponse('市町村追加エラー: ' + error.message);
  }
}

/**
 * 市町村を削除
 * 指定されたインデックスの市町村を削除し、後続のデータを詰める
 */
function handleDeleteMunicipality(data) {
  try {
    const index = data.index;

    if (index === undefined || index === null || index < 0) {
      return createErrorResponse('削除対象のインデックスが無効です');
    }

    const sheet = getSheet(SHEET_NAMES.MASTER);
    const startRow = 61;
    const targetRow = startRow + index;
    const maxRows = 50;

    // 削除対象行以降のデータを取得
    const remainingRows = maxRows - index - 1;
    if (remainingRows > 0) {
      const remaining = sheet.getRange(targetRow + 1, 17, remainingRows, 2).getValues();
      // 1行上にシフト
      sheet.getRange(targetRow, 17, remainingRows, 2).setValues(remaining);
    }

    // 最後の行をクリア
    const lastRow = startRow + maxRows - 1;
    sheet.getRange(lastRow, 17, 1, 2).clearContent();

    return createSuccessResponse({ message: '市町村を削除しました' });
  } catch (error) {
    return createErrorResponse('市町村削除エラー: ' + error.message);
  }
}

// === 請求データ出力 ===

/**
 * 請求データを出力
 * 選択した利用者の情報を「請求_2025」シートに出力
 */
function handleExecuteBilling(data) {
  try {
    const users = data.users || []; // 選択された利用者名の配列
    const yearMonth = data.yearMonth || ''; // YYYY-MM形式

    if (users.length === 0) {
      return createErrorResponse('利用者が選択されていません');
    }

    // 年度を取得（4月始まり）
    let year, month;
    if (yearMonth && yearMonth.match(/^\d{4}-\d{2}$/)) {
      [year, month] = yearMonth.split('-').map(Number);
    } else {
      const now = new Date();
      year = now.getFullYear();
      month = now.getMonth() + 1;
    }

    // 年度を計算（4月始まり：1-3月は前年度）
    const fiscalYear = month >= 4 ? year : year - 1;

    // 請求シートを取得（請求_YYYY形式）
    const billingSheetName = `請求_${fiscalYear}`;
    let billingSheet;
    try {
      billingSheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(billingSheetName);
      if (!billingSheet) {
        return createErrorResponse(`シート「${billingSheetName}」が見つかりません`);
      }
    } catch (e) {
      return createErrorResponse(`シート「${billingSheetName}」の取得に失敗しました: ${e.message}`);
    }

    // 名簿シートを取得
    const rosterSheetName = `名簿_${fiscalYear}`;
    let rosterSheet;
    try {
      rosterSheet = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(rosterSheetName);
      if (!rosterSheet) {
        return createErrorResponse(`シート「${rosterSheetName}」が見つかりません`);
      }
    } catch (e) {
      return createErrorResponse(`シート「${rosterSheetName}」の取得に失敗しました: ${e.message}`);
    }

    // 名簿シートから全データを一括取得（3行目〜最終行）
    const rosterLastRow = rosterSheet.getLastRow();
    const rosterNumRows = Math.max(0, rosterLastRow - 2);
    let rosterMap = {};

    if (rosterNumRows > 0) {
      const rosterData = rosterSheet.getRange(3, 1, rosterNumRows, 60).getValues();
      // 名前をキーにしたマップを作成
      for (let i = 0; i < rosterData.length; i++) {
        const name = rosterData[i][ROSTER_COLS.NAME - 1]; // B列
        if (name) {
          rosterMap[name] = rosterData[i];
        }
      }
    }

    // 出力設定: aₙ = 170 + 78(n−1) の法則
    const baseRow = 170;  // 開始行
    const interval = 78;  // 間隔

    // シートの最終行から最大人数を動的に計算
    const sheetLastRow = billingSheet.getMaxRows();
    const clearMaxUsers = Math.floor((sheetLastRow - baseRow) / interval) + 1;

    // 出力対象の行オフセット（baseRowからの相対位置）
    // B170〜B183の範囲で、B177とB180は除く
    const outputRowOffsets = [0, 1, 2, 3, 4, 5, 6, 8, 9, 11, 12, 13];

    // 前月データをクリア（出力対象セルのみ）
    for (let i = 0; i < clearMaxUsers; i++) {
      const userBaseRow = baseRow + (interval * i);
      // シートの範囲を超えないようにチェック
      if (userBaseRow + 13 > sheetLastRow) break;
      outputRowOffsets.forEach(offset => {
        billingSheet.getRange(userBaseRow + offset, 2).clearContent();
      });
    }

    // 利用者ごとにデータを出力
    users.forEach((name, index) => {
      const userBaseRow = baseRow + (interval * index);
      const rosterData = rosterMap[name];

      // B170: 氏名
      billingSheet.getRange(userBaseRow + 0, 2).setValue(name);

      if (rosterData) {
        // B171: フリガナ（名簿C列）
        billingSheet.getRange(userBaseRow + 1, 2).setValue(rosterData[ROSTER_COLS.NAME_KANA - 1] || '');

        // B172: 受給者証番号（名簿AA列）
        billingSheet.getRange(userBaseRow + 2, 2).setValue(rosterData[ROSTER_COLS.CERTIFICATE_NUMBER - 1] || '');

        // B173: 市町村および政令指定都市区（名簿O列&P列）
        const city = rosterData[ROSTER_COLS.CITY - 1] || '';
        const ward = rosterData[ROSTER_COLS.WARD - 1] || '';
        billingSheet.getRange(userBaseRow + 3, 2).setValue(city + ward);

        // B174: 障害支援区分（名簿AG列）
        billingSheet.getRange(userBaseRow + 4, 2).setValue(rosterData[ROSTER_COLS.SUPPORT_LEVEL - 1] || '');

        // B175: 利用者負担上限額（名簿AK列）
        billingSheet.getRange(userBaseRow + 5, 2).setValue(rosterData[ROSTER_COLS.USER_BURDEN_LIMIT - 1] || '');

        // B176: 利用開始日（名簿AH列）
        billingSheet.getRange(userBaseRow + 6, 2).setValue(rosterData[ROSTER_COLS.USE_START_DATE - 1] || '');

        // B178: 固定値「1」
        billingSheet.getRange(userBaseRow + 8, 2).setValue('1');

        // B179: 利用開始日（名簿AH列）
        billingSheet.getRange(userBaseRow + 9, 2).setValue(rosterData[ROSTER_COLS.USE_START_DATE - 1] || '');

        // B181: 支給決定期間有効期限（名簿AC列）
        billingSheet.getRange(userBaseRow + 11, 2).setValue(rosterData[ROSTER_COLS.DECISION_PERIOD2 - 1] || '');

        // B182: 適用期間有効期限（名簿AE列）
        billingSheet.getRange(userBaseRow + 12, 2).setValue(rosterData[ROSTER_COLS.APPLICABLE_END - 1] || '');

        // B183: 支給量（名簿AF列）
        billingSheet.getRange(userBaseRow + 13, 2).setValue(rosterData[ROSTER_COLS.SUPPLY_AMOUNT - 1] || '');
      }
    });

    return createSuccessResponse({
      message: `${users.length}名の利用者情報を出力しました`,
      sheetName: billingSheetName,
      count: users.length,
      outputRows: users.map((_, i) => baseRow + (interval * i))
    });
  } catch (error) {
    return createErrorResponse('請求データ出力エラー: ' + error.message);
  }
}
