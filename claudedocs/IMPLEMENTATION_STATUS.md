# 出勤支援アプリ 実装状況一覧

**最終更新**: 2026年1月4日

---

## 絶対ルール

### 1. パフォーマンス最優先
- 一括取得・一括書き込みを使用
- ループ内でのgetRange/setValueを避ける
- 不要なAPI呼び出しを避ける

### 2. GASファイル編集ルール
- **編集対象**: `assets/gas/gas_code_v4.js`
- **編集禁止**: ルート直下の `gas_code_v4.js`, `master_gas_code_*.js`（バックアップ専用）

---

## GAS APIエンドポイント一覧

### GET エンドポイント（実装済み）

| エンドポイント | ハンドラ関数 | 説明 |
|---------------|-------------|------|
| `master/users` | handleGetActiveUsers | 在籍中の利用者一覧取得 |
| `master/all-users` | handleGetAllUsers | 全利用者一覧取得（退所済み含む） |
| `master/dropdowns` | handleGetDropdownOptions | プルダウン選択肢取得 |
| `master/evaluation-alerts` | handleGetEvaluationAlerts | 評価アラート情報取得 |
| `staff/list` | handleGetStaffList | 職員一覧取得 |
| `attendance/daily/{date}` | handleGetDailyAttendance | 指定日の出勤一覧取得 |
| `attendance/scheduled/{date}` | handleGetScheduledUsers | 指定日の出勤予定者一覧取得 |
| `attendance/user/{userName}/{date}` | handleGetUserAttendance | 利用者の勤怠データ取得（高速） |
| `attendance/search/{userName}/{date}` | handleSearchUserAttendance | 利用者の勤怠データ検索（過去全範囲） |
| `attendance/history/{userName}` | handleGetUserHistory | 利用者の過去記録一覧取得 |
| `attendance/health-batch/{userNames}` | handleGetHealthBatch | 複数利用者の健康履歴バッチ取得 |
| `support/list/{date}` | handleGetSupportRecordList | 指定日の支援記録一覧取得 |
| `support/get/{date}/{userName}` | handleGetSupportRecord | 支援記録取得（高速） |
| `support/search/{date}/{userName}` | handleSearchSupportRecord | 支援記録検索（過去全範囲） |
| `chatwork/users` | handleGetChatworkUsers | Chatwork連携利用者一覧取得 |
| `analytics/facility-stats` | handleGetFacilityStats | 施設統計情報取得 |
| `analytics/weekly-schedule` | handleGetWeeklySchedule | 週間スケジュール取得 |
| `analytics/user-stats/{userName}` | handleGetUserStats | 利用者個別統計取得 |

### POST エンドポイント（実装済み）

| エンドポイント | ハンドラ関数 | 説明 |
|---------------|-------------|------|
| `auth/staff/login` | handleStaffLogin | 職員ログイン認証 |
| `staff/create` | handleCreateStaff | 職員新規作成 |
| `staff/update` | handleUpdateStaff | 職員情報更新 |
| `staff/delete` | handleDeleteStaff | 職員削除 |
| `user/list` | handleGetUserList | 利用者一覧取得（POST版） |
| `user/create` | handleCreateUser | 利用者新規作成 |
| `user/update` | handleUpdateUser | 利用者情報更新 |
| `user/change-status` | handleChangeUserStatus | 利用者契約状態変更 |
| `user/delete` | handleDeleteUser | 利用者削除 |
| `attendance/checkin` | handleCheckin | 出勤登録 |
| `attendance/checkout` | handleCheckout | 退勤登録 |
| `attendance/update` | handleUpdateAttendance | 勤怠データ更新 |
| `support/upsert` | handleUpsertSupportRecord | 支援記録作成/更新 |
| `chatwork/broadcast` | handleChatworkBroadcast | Chatworkメッセージ一斉送信 |
| `chatwork/set-api-key` | handleSetChatworkApiKey | ChatWork APIキー設定 |
| `fiscal-year/get-available` | handleGetAvailableFiscalYears | 利用可能年度一覧取得 |
| `fiscal-year/create-next` | handleCreateNextFiscalYear | 次年度スプレッドシート作成 |
| `billing/get-dropdowns` | handleGetBillingDropdowns | 請求業務用プルダウン取得 |
| `billing/save-settings` | handleSaveBillingSettings | 請求設定保存 |
| `billing/get-settings` | handleGetBillingSettings | 請求設定取得 |
| `billing/get-monthly-users` | handleGetMonthlyUsers | 月別利用者一覧取得 |
| `billing/execute` | handleExecuteBilling | 請求データ出力 |
| `municipality/get` | handleGetMunicipalities | 市町村一覧取得 |
| `municipality/add` | handleAddMunicipality | 市町村追加 |
| `municipality/delete` | handleDeleteMunicipality | 市町村削除 |
| `tasks/get` | handleGetTasks | 担当業務一覧取得 |
| `tasks/add` | handleAddTask | 担当業務追加 |
| `tasks/delete` | handleDeleteTask | 担当業務削除 |

---

## Flutter 画面一覧

### 利用者向け画面（/lib/screens/user/）

| ファイル名 | 画面名 | 状態 |
|-----------|--------|------|
| user_select_screen.dart | 利用者選択画面 | ✅ 実装済み |
| checkin_screen.dart | 出勤登録画面 | ✅ 実装済み |
| checkout_screen.dart | 退勤登録画面 | ✅ 実装済み |

### 支援者向け画面（/lib/screens/staff/）

| ファイル名 | 画面名 | 状態 |
|-----------|--------|------|
| login_screen.dart | ログイン画面 | ✅ 実装済み |
| daily_attendance_list_screen.dart | 本日の出勤一覧 | ✅ 実装済み |
| user_list_screen.dart | 利用者一覧 | ✅ 実装済み |
| user_detail_screen.dart | 利用者詳細・支援記録入力 | ✅ 実装済み |
| user_form_screen.dart | 利用者情報編集 | ✅ 実装済み |
| past_records_screen.dart | 過去実績画面 | ✅ 実装済み |
| chatwork_broadcast_screen.dart | Chatwork連絡画面 | ✅ 実装済み |
| analytics_screen.dart | 分析画面 | ✅ 実装済み |

### 施設管理者向け画面（/lib/screens/facility_admin/）

| ファイル名 | 画面名 | 状態 |
|-----------|--------|------|
| facility_admin_dashboard_screen.dart | 施設管理者ダッシュボード | ✅ 実装済み |
| staff_list_screen.dart | 職員一覧 | ✅ 実装済み |
| staff_form_screen.dart | 職員登録/編集 | ✅ 実装済み |
| user_list_screen.dart | 利用者一覧（管理者用） | ✅ 実装済み |
| user_form_screen.dart | 利用者登録/編集（管理者用） | ✅ 実装済み |
| daily_attendance_screen.dart | 本日の出勤一覧（管理者用） | ✅ 実装済み |
| chatwork_settings_screen.dart | Chatwork設定画面 | ✅ 実装済み |
| analytics_screen.dart | 統計・分析画面 | ✅ 実装済み |
| settings_screen.dart | 年度管理設定画面 | ✅ 実装済み |
| fiscal_year_setup_wizard_screen.dart | 次年度GASセットアップウィザード | ✅ 実装済み |
| billing_settings_screen.dart | 請求業務設定・実行画面 | ✅ 実装済み |

### 全権管理者向け画面（/lib/screens/superadmin/）

| ファイル名 | 画面名 | 状態 |
|-----------|--------|------|
| super_admin_login_screen.dart | 全権管理者ログイン | ✅ 実装済み |
| super_admin_dashboard_screen.dart | 全権管理者ダッシュボード | ✅ 実装済み |
| facility_registration_screen.dart | 施設新規登録 | ✅ 実装済み |
| facility_edit_screen.dart | 施設編集 | ✅ 実装済み |
| facility_code_setup_screen.dart | 施設コード設定 | ✅ 実装済み |
| facility_setup_wizard_screen.dart | 施設セットアップウィザード | ✅ 実装済み |
| admin_login_screen.dart | 管理者ログイン | ✅ 実装済み |

### 共通画面（/lib/screens/common/）

| ファイル名 | 画面名 | 状態 |
|-----------|--------|------|
| menu_selection_screen.dart | メニュー選択画面 | ✅ 実装済み |
| tasks_settings_screen.dart | 担当業務設定画面 | ✅ 実装済み |

---

## Flutter サービス一覧

### サービスファイル（/lib/services/）

| ファイル名 | 説明 | 状態 |
|-----------|------|------|
| api_service.dart | API通信基盤 | ✅ 実装済み |
| auth_service.dart | 認証サービス | ✅ 実装済み |
| attendance_service.dart | 勤怠サービス | ✅ 実装済み |
| support_service.dart | 支援記録サービス | ✅ 実装済み |
| master_service.dart | マスタデータサービス | ✅ 実装済み |
| staff_service.dart | 職員管理サービス | ✅ 実装済み |
| user_service.dart | 利用者管理サービス | ✅ 実装済み |
| facility_service.dart | 施設管理サービス | ✅ 実装済み |
| master_api_service.dart | 全権管理者APIサービス | ✅ 実装済み |
| master_auth_service.dart | 全権管理者認証サービス | ✅ 実装済み |
| fiscal_year_service.dart | 年度管理サービス | ✅ 実装済み |
| billing_service.dart | 請求業務サービス | ✅ 実装済み |
| tasks_service.dart | 担当業務管理サービス | ✅ 実装済み |

---

## 実装済み機能一覧

### 利用者機能
- [x] 利用者選択・ログイン
- [x] 出勤登録（体調、睡眠、コメント、業務選択）
- [x] 退勤登録（疲労、ストレス、コメント、休憩時間）
- [x] 勤務時間自動計算

### 支援者機能
- [x] 職員ログイン（メール/パスワード認証）
- [x] 本日の出勤一覧表示
- [x] 出勤予定者一覧表示
- [x] 利用者詳細・支援記録入力
- [x] 利用者情報編集（全フィールド対応）
- [x] 過去実績検索・編集
- [x] Chatwork一斉連絡
- [x] 分析機能（施設統計、個人統計、週間スケジュール）
- [x] 評価アラート表示
- [x] 担当業務設定（マスタ設定L列の選択肢管理）

### 施設管理者機能
- [x] 施設管理者ダッシュボード
- [x] 職員一覧・登録・編集・削除
- [x] 退職済み職員のログイン拒否
- [x] 利用者一覧・登録・編集・削除・契約状態変更
- [x] 本日の出勤一覧（支援記録入力可）
- [x] Chatwork APIキー設定
- [x] 統計・分析画面
- [x] 年度管理設定画面
- [x] 次年度スプレッドシート作成機能
- [x] 次年度GASセットアップウィザード
- [x] 請求業務設定画面
- [x] 請求データ出力（名簿情報を請求シートに78行間隔で出力）
- [x] 請求シートExcelダウンロード（xlsx形式、フォーマット保持）
- [x] 市町村情報管理
- [x] 担当業務設定（マスタ設定L列の選択肢管理）

### 全権管理者機能
- [x] 全権管理者ログイン
- [x] 施設一覧表示
- [x] 施設新規登録
- [x] 施設情報編集
- [x] 施設コード設定
- [x] 施設セットアップウィザード

### パフォーマンス最適化（実装済み）
- [x] handleGetStaffList - 一括取得化（768回→1回）
- [x] handleGetUserList - 一括取得化（4000+回→2回）
- [x] handleCreateStaff/handleUpdateStaff - 一括読み書き化
- [x] handleCreateUser/handleUpdateUser - 一括読み書き化
- [x] handleChangeUserStatus - ループ内getValue削除
- [x] handleDeleteUser - 一括クリア化（10回→1回）
- [x] deleteFromRosterSheet - ループ内getValue削除
- [x] writeToRosterSheetBatch - 新規作成（50+回→1回）
- [x] プルダウンキャッシュ（デバッグ5分/本番24時間）
- [x] 利用者キャッシュ（デバッグ5分/本番1時間）

### 自動処理
- [x] 退所日入力時に契約状態を自動で「退所済み」に変更

---

## データモデル一覧

| ファイル名 | モデル名 | 説明 |
|-----------|---------|------|
| user.dart | User | 利用者情報 |
| staff.dart | Staff | 職員情報 |
| attendance.dart | Attendance | 勤怠データ |
| support_record.dart | SupportRecord | 支援記録 |
| dropdown_options.dart | DropdownOptions | プルダウン選択肢 |
| facility.dart | Facility | 施設情報 |
| facility_admin.dart | FacilityAdmin | 施設管理者情報 |
| super_admin.dart | SuperAdmin | 全権管理者情報 |
| admin_login_result.dart | AdminLoginResult | ログイン結果 |

---

## シート構成

### マスタ設定シート
- 利用者データ: 8行目〜、A〜J列（名前、フリガナ、契約状態、曜日別予定）
- 職員データ: 8行目〜、V〜Z列（名前、権限、メール、パスワード、職種）
- プルダウン選択肢: 複数セクション（体調、睡眠、疲労、ストレス、曜日予定、勤務地等）

### 支援記録_2025シート
- A〜AL列（日時、利用者名、出欠、業務、体調、時刻、加算、評価等）

### 名簿_2025シート
- A〜BH列（基本情報、連絡先、住所、詳細情報、関係機関、銀行情報、退所情報等）

### 請求_2025シート（出力先）

請求データ出力時、78行間隔で利用者情報を出力（aₙ = 170 + 78(n−1)の法則）

#### Excelダウンロード機能
- GASで請求シートをxlsx形式でエクスポート（フォーマット完全保持）
- Base64エンコードでFlutterに転送
- macOS/Windowsはダウンロードフォルダに直接保存
- 出力ファイル: `請求データ_YYYYMM.xlsx`（「請求」タブのみ）

| 行オフセット | 内容 | 参照元 |
|------------|------|--------|
| +0 | 氏名 | 選択した利用者名 |
| +1 | フリガナ | 名簿C列 |
| +2 | 受給者証番号 | 名簿AA列 |
| +3 | 市町村＋政令指定都市区 | 名簿O列＋P列 |
| +4 | 障害支援区分 | 名簿AG列 |
| +5 | 利用者負担上限額 | 名簿AK列 |
| +6 | 利用開始日 | 名簿AH列 |
| +8 | 「1」（固定値） | - |
| +9 | 利用開始日 | 名簿AH列 |
| +11 | 支給決定期間有効期限 | 名簿AC列 |
| +12 | 適用期間有効期限 | 名簿AE列 |
| +13 | 支給量 | 名簿AF列 |

※B177（+7）、B180（+10）はスキップ

---

## 未実装・検討中の機能

現時点で未実装の機能はありません。
今後の機能追加要望があれば、このセクションに追記してください。

---

## ファイルパス

### 編集対象GAS
```
assets/gas/gas_code_v4.js
```

### 編集禁止（バックアップ）
```
gas_code_v4.js
master_gas_code_final.js
```

### ドキュメント
```
CLAUDE.md - プロジェクトルール（簡易版）
claudedocs/IMPLEMENTATION_STATUS.md - 実装状況一覧（このファイル）
claudedocs/PROJECT_SUMMARY.md - プロジェクトサマリー
```
