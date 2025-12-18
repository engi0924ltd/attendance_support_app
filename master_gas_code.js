/**
 * 全施設管理マスター用 Google Apps Script
 *
 * 機能:
 * - 全施設管理者（スーパー管理者）の認証
 * - 施設の登録・更新・削除
 * - 施設一覧の取得
 */

// ========================================
// 設定定数
// ========================================

const MASTER_SHEET_CONFIG = {
  // シート名
  FACILITY_MASTER_SHEET: '施設マスタ',
  SUPER_ADMIN_SHEET: '全施設管理者',
  SYSTEM_CONFIG_SHEET: 'システム設定',

  // 施設マスタシートの列
  FACILITY_COLS: {
    FACILITY_ID: 1,        // A列: 施設ID（厚労省番号）
    FACILITY_NAME: 2,      // B列: 施設名
    ADMIN_NAME: 3,         // C列: 施設管理者名
    ADMIN_EMAIL: 4,        // D列: 施設メールアドレス
    ADMIN_PASSWORD: 5,     // E列: 施設パスワード
    SPREADSHEET_ID: 6,     // F列: スプレッドシートID
    FISCAL_YEAR: 7,        // G列: 年度
    CREATED_AT: 8,         // H列: 作成日時
    UPDATED_AT: 9,         // I列: 更新日時
    STATUS: 10,            // J列: ステータス
    MEMO: 11,              // K列: 備考
    DRIVE_FOLDER_ID: 12,   // L列: ドライブフォルダID
    ADDRESS: 13,           // M列: 施設住所
    PHONE: 14,             // N列: 施設電話番号
    CONTRACT_START: 15,    // O列: 契約開始日
    CONTRACT_END: 16,      // P列: 契約終了日
    CAPACITY: 17,          // Q列: 利用者定員
    TEMPLATE_ID: 18        // R列: テンプレートID
  },

  // 全施設管理者シートの列
  SUPER_ADMIN_COLS: {
    ADMIN_ID: 1,           // A列: 管理者ID
    ADMIN_NAME: 2,         // B列: 管理者名
    EMAIL: 3,              // C列: メールアドレス
    PASSWORD: 4,           // D列: パスワード
    PERMISSION_LEVEL: 5,   // E列: 権限レベル（固定値: 0）
    CREATED_AT: 6,         // F列: 作成日時
    UPDATED_AT: 7,         // G列: 更新日時
    STATUS: 8,             // H列: ステータス
    MEMO: 9                // I列: 備考
  },

  // データ開始行（2行目から）
  DATA_START_ROW: 2
};

// ========================================
// メイン処理（HTTPリクエストのエントリーポイント）
// ========================================

/**
 * POSTリクエストのハンドラー
 */
function doPost(e) {
  try {
    const requestData = JSON.parse(e.postData.contents);
    const endpoint = requestData.endpoint;
    const data = requestData.data;

    Logger.log('=== POST Request ===');
    Logger.log('Endpoint: ' + endpoint);
    Logger.log('Data: ' + JSON.stringify(data));

    let response;

    switch (endpoint) {
      case 'auth/superadmin/login':
        response = handleSuperAdminLogin(data);
        break;
      case 'auth/admin/login':
        response = handleUnifiedAdminLogin(data);
        break;
      case 'facility/create':
        response = handleCreateFacility(data);
        break;
      case 'facility/update':
        response = handleUpdateFacility(data);
        break;
      case 'facility/delete':
        response = handleDeleteFacility(data);
        break;
      default:
        response = createErrorResponse('不明なエンドポイントです: ' + endpoint);
    }

    return ContentService.createTextOutput(JSON.stringify(response))
      .setMimeType(ContentService.MimeType.JSON);

  } catch (error) {
    Logger.log('=== ERROR in doPost ===');
    Logger.log('Error: ' + error.toString());
    return ContentService.createTextOutput(
      JSON.stringify(createErrorResponse('サーバーエラー: ' + error.toString()))
    ).setMimeType(ContentService.MimeType.JSON);
  }
}

/**
 * GETリクエストのハンドラー
 */
function doGet(e) {
  try {
    const endpoint = e.parameter.endpoint;

    Logger.log('=== GET Request ===');
    Logger.log('Endpoint: ' + endpoint);

    let response;

    switch (endpoint) {
      case 'facilities':
        response = handleGetFacilities();
        break;
      case 'facility':
        const facilityId = e.parameter.facilityId;
        response = handleGetFacility(facilityId);
        break;
      default:
        response = createErrorResponse('不明なエンドポイントです: ' + endpoint);
    }

    return ContentService.createTextOutput(JSON.stringify(response))
      .setMimeType(ContentService.MimeType.JSON);

  } catch (error) {
    Logger.log('=== ERROR in doGet ===');
    Logger.log('Error: ' + error.toString());
    return ContentService.createTextOutput(
      JSON.stringify(createErrorResponse('サーバーエラー: ' + error.toString()))
    ).setMimeType(ContentService.MimeType.JSON);
  }
}

// ========================================
// 認証関連
// ========================================

/**
 * 統合管理者ログイン処理（全権管理者 or 施設管理者）
 */
function handleUnifiedAdminLogin(data) {
  const email = data.email;
  const password = data.password;

  Logger.log('=== Unified Admin Login Attempt ===');
  Logger.log('Email: ' + email);

  // バリデーション
  if (!email || !password) {
    return createErrorResponse('メールアドレスとパスワードを入力してください');
  }

  const ss = SpreadsheetApp.getActiveSpreadsheet();

  // 1. まず全権管理者シートをチェック
  const superAdminSheet = ss.getSheetByName(MASTER_SHEET_CONFIG.SUPER_ADMIN_SHEET);
  if (superAdminSheet) {
    const superAdminResult = checkSuperAdminLogin(superAdminSheet, email, password);
    if (superAdminResult) {
      Logger.log('Super Admin login successful');
      return superAdminResult;
    }
  }

  // 2. 全権管理者でなければ施設マスタシートをチェック
  const facilitySheet = ss.getSheetByName(MASTER_SHEET_CONFIG.FACILITY_MASTER_SHEET);
  if (facilitySheet) {
    const facilityAdminResult = checkFacilityAdminLogin(facilitySheet, email, password);
    if (facilityAdminResult) {
      Logger.log('Facility Admin login successful');
      return facilityAdminResult;
    }
  }

  // 3. どちらにも該当しない
  Logger.log('Login failed: Email not found or password mismatch');
  return createErrorResponse('メールアドレスまたはパスワードが正しくありません');
}

/**
 * 全権管理者シートでログインチェック
 */
function checkSuperAdminLogin(sheet, email, password) {
  const lastRow = sheet.getLastRow();

  for (let row = MASTER_SHEET_CONFIG.DATA_START_ROW; row <= lastRow; row++) {
    const adminEmail = sheet.getRange(row, MASTER_SHEET_CONFIG.SUPER_ADMIN_COLS.EMAIL).getValue();
    const adminPassword = sheet.getRange(row, MASTER_SHEET_CONFIG.SUPER_ADMIN_COLS.PASSWORD).getValue();
    const status = sheet.getRange(row, MASTER_SHEET_CONFIG.SUPER_ADMIN_COLS.STATUS).getValue();

    if (adminEmail && adminEmail === email) {
      // ステータスチェック
      if (status !== '有効') {
        return null; // 無効なアカウント
      }

      // パスワードチェック
      if (adminPassword && adminPassword === password) {
        const adminId = sheet.getRange(row, MASTER_SHEET_CONFIG.SUPER_ADMIN_COLS.ADMIN_ID).getValue();
        const adminName = sheet.getRange(row, MASTER_SHEET_CONFIG.SUPER_ADMIN_COLS.ADMIN_NAME).getValue();
        const permissionLevel = sheet.getRange(row, MASTER_SHEET_CONFIG.SUPER_ADMIN_COLS.PERMISSION_LEVEL).getValue();

        const token = Utilities.base64Encode(adminId + ':' + new Date().getTime());

        return createSuccessResponse({
          accountType: 'super_admin',
          adminId: adminId || '',
          adminName: adminName || '',
          email: adminEmail,
          permissionLevel: permissionLevel,
          token: token
        });
      }
    }
  }

  return null; // 見つからない
}

/**
 * 施設マスタシートでログインチェック
 */
function checkFacilityAdminLogin(sheet, email, password) {
  const lastRow = sheet.getLastRow();

  for (let row = MASTER_SHEET_CONFIG.DATA_START_ROW; row <= lastRow; row++) {
    const adminEmail = sheet.getRange(row, MASTER_SHEET_CONFIG.FACILITY_COLS.ADMIN_EMAIL).getValue();
    const adminPassword = sheet.getRange(row, MASTER_SHEET_CONFIG.FACILITY_COLS.ADMIN_PASSWORD).getValue();
    const status = sheet.getRange(row, MASTER_SHEET_CONFIG.FACILITY_COLS.STATUS).getValue();

    if (adminEmail && adminEmail === email) {
      // ステータスチェック
      if (status !== '有効') {
        return null; // 無効な施設
      }

      // パスワードチェック
      if (adminPassword && adminPassword === password) {
        const facilityId = sheet.getRange(row, MASTER_SHEET_CONFIG.FACILITY_COLS.FACILITY_ID).getValue();
        const facilityName = sheet.getRange(row, MASTER_SHEET_CONFIG.FACILITY_COLS.FACILITY_NAME).getValue();
        const adminName = sheet.getRange(row, MASTER_SHEET_CONFIG.FACILITY_COLS.ADMIN_NAME).getValue();
        const spreadsheetId = sheet.getRange(row, MASTER_SHEET_CONFIG.FACILITY_COLS.SPREADSHEET_ID).getValue();
        const fiscalYear = sheet.getRange(row, MASTER_SHEET_CONFIG.FACILITY_COLS.FISCAL_YEAR).getValue();

        const token = Utilities.base64Encode(facilityId + ':' + new Date().getTime());

        return createSuccessResponse({
          accountType: 'facility_admin',
          facilityId: facilityId || '',
          facilityName: facilityName || '',
          adminName: adminName || '',
          email: adminEmail,
          permissionLevel: 1, // 施設管理者
          spreadsheetId: spreadsheetId || '',
          fiscalYear: fiscalYear || '',
          token: token
        });
      }
    }
  }

  return null; // 見つからない
}

/**
 * 全施設管理者（スーパー管理者）のログイン処理
 */
function handleSuperAdminLogin(data) {
  const email = data.email;
  const password = data.password;

  Logger.log('=== Super Admin Login Attempt ===');
  Logger.log('Email: ' + email);

  // バリデーション
  if (!email || !password) {
    return createErrorResponse('メールアドレスとパスワードを入力してください');
  }

  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName(MASTER_SHEET_CONFIG.SUPER_ADMIN_SHEET);

  if (!sheet) {
    Logger.log('ERROR: Super Admin sheet not found');
    return createErrorResponse('システムエラー: 全施設管理者シートが見つかりません');
  }

  const lastRow = sheet.getLastRow();
  Logger.log('Last row: ' + lastRow);

  // 全施設管理者アカウントを検索
  for (let row = MASTER_SHEET_CONFIG.DATA_START_ROW; row <= lastRow; row++) {
    const adminEmail = sheet.getRange(row, MASTER_SHEET_CONFIG.SUPER_ADMIN_COLS.EMAIL).getValue();
    const adminPassword = sheet.getRange(row, MASTER_SHEET_CONFIG.SUPER_ADMIN_COLS.PASSWORD).getValue();
    const status = sheet.getRange(row, MASTER_SHEET_CONFIG.SUPER_ADMIN_COLS.STATUS).getValue();

    Logger.log('Row ' + row + ': ' + adminEmail);

    if (adminEmail && adminEmail === email) {
      Logger.log('Email matched!');

      // ステータスチェック
      if (status !== '有効') {
        return createErrorResponse('このアカウントは無効化されています');
      }

      // パスワードチェック
      if (adminPassword && adminPassword === password) {
        Logger.log('Password matched! Login successful');

        const adminId = sheet.getRange(row, MASTER_SHEET_CONFIG.SUPER_ADMIN_COLS.ADMIN_ID).getValue();
        const adminName = sheet.getRange(row, MASTER_SHEET_CONFIG.SUPER_ADMIN_COLS.ADMIN_NAME).getValue();
        const permissionLevel = sheet.getRange(row, MASTER_SHEET_CONFIG.SUPER_ADMIN_COLS.PERMISSION_LEVEL).getValue();

        // トークン生成（簡易版: 実際にはより安全な方法を使用）
        const token = Utilities.base64Encode(adminId + ':' + new Date().getTime());

        return createSuccessResponse({
          adminId: adminId || '',
          adminName: adminName || '',
          email: adminEmail,
          permissionLevel: permissionLevel,
          token: token
        });
      } else {
        Logger.log('Password mismatch');
        return createErrorResponse('パスワードが正しくありません');
      }
    }
  }

  Logger.log('Email not found');
  return createErrorResponse('メールアドレスが登録されていません');
}

// ========================================
// 施設管理関連
// ========================================

/**
 * 全施設一覧を取得
 */
function handleGetFacilities() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName(MASTER_SHEET_CONFIG.FACILITY_MASTER_SHEET);

  if (!sheet) {
    return createErrorResponse('システムエラー: 施設マスタシートが見つかりません');
  }

  const lastRow = sheet.getLastRow();

  if (lastRow < MASTER_SHEET_CONFIG.DATA_START_ROW) {
    // データがない場合は空配列を返す
    return createSuccessResponse({ facilities: [] });
  }

  const facilities = [];

  for (let row = MASTER_SHEET_CONFIG.DATA_START_ROW; row <= lastRow; row++) {
    const facility = parseFacilityRow(sheet, row);

    // 有効な施設のみ返す
    if (facility.status === '有効') {
      facilities.push(facility);
    }
  }

  return createSuccessResponse({ facilities: facilities });
}

/**
 * 特定施設の情報を取得
 */
function handleGetFacility(facilityId) {
  if (!facilityId) {
    return createErrorResponse('施設IDが指定されていません');
  }

  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const sheet = ss.getSheetByName(MASTER_SHEET_CONFIG.FACILITY_MASTER_SHEET);

  if (!sheet) {
    return createErrorResponse('システムエラー: 施設マスタシートが見つかりません');
  }

  const lastRow = sheet.getLastRow();

  for (let row = MASTER_SHEET_CONFIG.DATA_START_ROW; row <= lastRow; row++) {
    const rowFacilityId = sheet.getRange(row, MASTER_SHEET_CONFIG.FACILITY_COLS.FACILITY_ID).getValue();

    if (rowFacilityId && rowFacilityId.toString() === facilityId.toString()) {
      const facility = parseFacilityRow(sheet, row);
      return createSuccessResponse({ facility: facility });
    }
  }

  return createErrorResponse('施設が見つかりません');
}

/**
 * 新規施設を登録
 */
function handleCreateFacility(data) {
  try {
    Logger.log('=== Create Facility ===');
    Logger.log('Data: ' + JSON.stringify(data));

    // バリデーション
    if (!data.facilityId) {
      return createErrorResponse('施設ID（厚労省番号）を入力してください');
    }
    if (!data.facilityName) {
      return createErrorResponse('施設名を入力してください');
    }
    if (!data.adminName) {
      return createErrorResponse('施設管理者名を入力してください');
    }
    if (!data.adminEmail) {
      return createErrorResponse('メールアドレスを入力してください');
    }
    if (!data.adminPassword) {
      return createErrorResponse('パスワードを入力してください');
    }
    if (!data.fiscalYear) {
      return createErrorResponse('年度を入力してください');
    }

    const ss = SpreadsheetApp.getActiveSpreadsheet();
    const facilitySheet = ss.getSheetByName(MASTER_SHEET_CONFIG.FACILITY_MASTER_SHEET);

    if (!facilitySheet) {
      return createErrorResponse('システムエラー: 施設マスタシートが見つかりません');
    }

    // 1. 施設IDの重複チェック
    const lastRow = facilitySheet.getLastRow();
    for (let row = MASTER_SHEET_CONFIG.DATA_START_ROW; row <= lastRow; row++) {
      const existingFacilityId = facilitySheet.getRange(row, MASTER_SHEET_CONFIG.FACILITY_COLS.FACILITY_ID).getValue();
      if (existingFacilityId && existingFacilityId.toString() === data.facilityId.toString()) {
        return createErrorResponse('この施設IDは既に登録されています');
      }
    }

    // 2. メールアドレスの重複チェック
    for (let row = MASTER_SHEET_CONFIG.DATA_START_ROW; row <= lastRow; row++) {
      const existingEmail = facilitySheet.getRange(row, MASTER_SHEET_CONFIG.FACILITY_COLS.ADMIN_EMAIL).getValue();
      if (existingEmail && existingEmail.toLowerCase() === data.adminEmail.toLowerCase()) {
        return createErrorResponse('このメールアドレスは既に登録されています');
      }
    }

    // 3. テンプレートスプレッドシートをコピー
    const templateId = data.templateId || '1GSyuEUl_Jn5NaNUcSEIF8oyqN2H9GTAPzDCbb_7C0_o';
    let newSpreadsheetId;

    try {
      const templateFile = DriveApp.getFileById(templateId);
      const newFileName = data.facilityName + '_マスタ設定_' + data.fiscalYear;

      // ドライブフォルダIDが指定されている場合はそこにコピー
      let newFile;
      if (data.driveFolderId) {
        const folder = DriveApp.getFolderById(data.driveFolderId);
        newFile = templateFile.makeCopy(newFileName, folder);
      } else {
        // フォルダ未指定の場合はマイドライブのルートにコピー
        newFile = templateFile.makeCopy(newFileName);
      }

      newSpreadsheetId = newFile.getId();
      Logger.log('New spreadsheet created: ' + newSpreadsheetId);

    } catch (error) {
      Logger.log('ERROR copying template: ' + error.toString());
      return createErrorResponse('テンプレートのコピーに失敗しました: ' + error.toString());
    }

    // 4. 施設マスタシートに新しい行を追加
    const newRow = lastRow + 1;
    const now = new Date();
    const cols = MASTER_SHEET_CONFIG.FACILITY_COLS;

    facilitySheet.getRange(newRow, cols.FACILITY_ID).setValue(data.facilityId);
    facilitySheet.getRange(newRow, cols.FACILITY_NAME).setValue(data.facilityName);
    facilitySheet.getRange(newRow, cols.ADMIN_NAME).setValue(data.adminName);
    facilitySheet.getRange(newRow, cols.ADMIN_EMAIL).setValue(data.adminEmail);
    facilitySheet.getRange(newRow, cols.ADMIN_PASSWORD).setValue(data.adminPassword);
    facilitySheet.getRange(newRow, cols.SPREADSHEET_ID).setValue(newSpreadsheetId);
    facilitySheet.getRange(newRow, cols.FISCAL_YEAR).setValue(data.fiscalYear);
    facilitySheet.getRange(newRow, cols.CREATED_AT).setValue(now);
    facilitySheet.getRange(newRow, cols.UPDATED_AT).setValue(now);
    facilitySheet.getRange(newRow, cols.STATUS).setValue('有効');
    facilitySheet.getRange(newRow, cols.MEMO).setValue(data.memo || '');
    facilitySheet.getRange(newRow, cols.DRIVE_FOLDER_ID).setValue(data.driveFolderId || '');
    facilitySheet.getRange(newRow, cols.ADDRESS).setValue(data.address || '');
    facilitySheet.getRange(newRow, cols.PHONE).setValue(data.phone || '');
    facilitySheet.getRange(newRow, cols.CONTRACT_START).setValue(data.contractStart || '');
    facilitySheet.getRange(newRow, cols.CONTRACT_END).setValue(data.contractEnd || '');
    facilitySheet.getRange(newRow, cols.CAPACITY).setValue(data.capacity || '');
    facilitySheet.getRange(newRow, cols.TEMPLATE_ID).setValue(templateId);

    Logger.log('Facility registered successfully');

    return createSuccessResponse({
      message: '施設を登録しました',
      facilityId: data.facilityId,
      spreadsheetId: newSpreadsheetId,
      facility: parseFacilityRow(facilitySheet, newRow)
    });

  } catch (error) {
    Logger.log('ERROR in handleCreateFacility: ' + error.toString());
    return createErrorResponse('施設登録エラー: ' + error.toString());
  }
}

/**
 * 施設情報を更新
 */
function handleUpdateFacility(data) {
  // 実装は次のフェーズで追加
  return createErrorResponse('この機能は実装予定です');
}

/**
 * 施設を削除（論理削除）
 */
function handleDeleteFacility(data) {
  // 実装は次のフェーズで追加
  return createErrorResponse('この機能は実装予定です');
}

// ========================================
// ユーティリティ関数
// ========================================

/**
 * 施設マスタシートの1行をパースして施設オブジェクトに変換
 */
function parseFacilityRow(sheet, row) {
  const cols = MASTER_SHEET_CONFIG.FACILITY_COLS;

  return {
    facilityId: toStringOrNull(sheet.getRange(row, cols.FACILITY_ID).getValue()),
    facilityName: toStringOrNull(sheet.getRange(row, cols.FACILITY_NAME).getValue()),
    adminName: toStringOrNull(sheet.getRange(row, cols.ADMIN_NAME).getValue()),
    adminEmail: toStringOrNull(sheet.getRange(row, cols.ADMIN_EMAIL).getValue()),
    spreadsheetId: toStringOrNull(sheet.getRange(row, cols.SPREADSHEET_ID).getValue()),
    fiscalYear: toStringOrNull(sheet.getRange(row, cols.FISCAL_YEAR).getValue()),
    permissionLevel: 1, // 固定値: 施設管理者
    createdAt: toStringOrNull(sheet.getRange(row, cols.CREATED_AT).getValue()),
    updatedAt: toStringOrNull(sheet.getRange(row, cols.UPDATED_AT).getValue()),
    status: toStringOrNull(sheet.getRange(row, cols.STATUS).getValue()),
    memo: toStringOrNull(sheet.getRange(row, cols.MEMO).getValue()),
    driveFolderId: toStringOrNull(sheet.getRange(row, cols.DRIVE_FOLDER_ID).getValue()),
    address: toStringOrNull(sheet.getRange(row, cols.ADDRESS).getValue()),
    phone: toStringOrNull(sheet.getRange(row, cols.PHONE).getValue()),
    contractStart: toStringOrNull(sheet.getRange(row, cols.CONTRACT_START).getValue()),
    contractEnd: toStringOrNull(sheet.getRange(row, cols.CONTRACT_END).getValue()),
    capacity: sheet.getRange(row, cols.CAPACITY).getValue() || null,
    templateId: toStringOrNull(sheet.getRange(row, cols.TEMPLATE_ID).getValue())
  };
}

/**
 * 値を文字列に変換（nullの場合はnullを返す）
 */
function toStringOrNull(value) {
  if (value === null || value === undefined || value === '') {
    return null;
  }
  return String(value);
}

/**
 * 成功レスポンスを生成
 */
function createSuccessResponse(data) {
  return {
    success: true,
    data: data
  };
}

/**
 * エラーレスポンスを生成
 */
function createErrorResponse(message) {
  return {
    success: false,
    error: message
  };
}
