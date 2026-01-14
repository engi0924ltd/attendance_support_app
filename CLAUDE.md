# 出勤支援アプリ - プロジェクトルール

## 絶対ルール

### 1. パフォーマンス最優先
**アプリとGASの読み込み・書き出し速度を何より優先する**
- 一括取得・一括書き込みを使用
- ループ内でのgetRange/setValueを避ける
- 不要なAPI呼び出しを避ける

### 2. GASファイル編集ルール
- **編集対象**: `assets/gas/gas_code_v4.js`
- **編集禁止**: ルート直下の `gas_code_v4.js`, `master_gas_code_*.js` は**バックアップ専用**

### 3. GASデプロイルール（重要）
- **`assets/gas/gas_code_v4.js`** = **施設のスプレッドシート用GAS**
  - 対象シート: マスタ設定、名簿_YYYY、支援記録_YYYY、請求_YYYY など
  - デプロイ方法: 全権管理者画面 → 対象施設の「GAS更新」ボタン
  - **全権管理者シートのGASではない！施設のスプレッドシートのGASを更新する**
- **`master_gas_code_*.js`** = **全権管理者シート用GAS**（通常は編集しない）
- GAS変更後は**必ずどのシートのGASを更新するか明示**すること

### 4. GASデバッグルール
- **GASの「実行数」からログは確認できない**
- デバッグ時は**APIレスポンスにデバッグ情報を含めて**Flutterログで確認する
- `console.log`ではなく、レスポンスの`debug`フィールドに情報を入れる

### 5. デザイン切り替えルール
- ユーザーが「**戻して**」と言ったら、即座に`git checkout main`でスタンダードデザイン（青いグラデーション）に戻す
- ポップなデザインは`feature/pop-design`ブランチで作業
- `main`ブランチ = スタンダードデザイン（青）を維持

### 6. コード編集ルール（重要）
**コードを編集する際には、編集前に必ず編集内容をユーザーに提示して確認を取ること**
- 何を変更しようとしているか
- どのファイルのどの部分か
- 変更前と変更後の概要

**修正については必ず指定された修正のみを行うこと**
- 別途修正が必要な場合は、必ず修正が必要な理由をユーザーに提示して承諾を求める
- 勝手に追加の修正や改善を行わない

---

## クイックステータス仕様（詳細）

### 概要
支援者画面と施設管理者ダッシュボードで表示される4つのステータスカード。
**両画面で必ず同じ数値を表示するため、共通ヘルパー関数を使用する。**

### 使用ファイル
| ファイル | 役割 |
|---------|------|
| `lib/utils/quick_status_helper.dart` | 共通計算ロジック（**必ずこれを使用**） |
| `lib/screens/staff/daily_attendance_list_screen.dart` | 支援者画面 |
| `lib/screens/facility_admin/facility_admin_dashboard_screen_v2.dart` | 施設管理者画面 |

### 各項目の定義と詳細カウント方法

---

#### 1. 出勤予定（scheduled）

| 項目 | 内容 |
|------|------|
| 定義 | その日に出勤予定がある利用者の人数 |
| 参照元 | マスタ設定シート D〜J列（曜日別予定） |
| 特記事項 | **出勤しても減らない固定値**。その日の曜日に予定がある全員をカウント |

**GAS側での取得（getScheduledUsers関数）:**
```javascript
// マスタ設定シートから曜日別予定を取得
// D列=日曜, E列=月曜, F列=火曜, G列=水曜, H列=木曜, I列=金曜, J列=土曜
const dayOfWeek = new Date(dateStr).getDay(); // 0=日曜〜6=土曜
const scheduleColIndex = 3 + dayOfWeek; // D列(index 3) + 曜日

// 予定が空でない人をscheduledUsersに追加
if (row[scheduleColIndex] && row[scheduleColIndex].toString().trim() !== '') {
  scheduledUsers.push({ userName, scheduledAttendance, hasCheckedIn, attendance });
}
```

**Flutter側での計算:**
```dart
// quick_status_helper.dart
int scheduled = 0;
for (final user in scheduledUsers) {
  scheduled++;  // scheduledUsersの人数をそのままカウント
}
// 結果: scheduled = scheduledUsers.length
```

---

#### 2. 出勤済（checkedIn）

| 項目 | 内容 |
|------|------|
| 定義 | その日に支援記録が作成されている人数 |
| 参照元 | 支援記録_YYYYシート（その日の日付で絞り込み） |
| 特記事項 | **予定外出勤（非利用日の人）も含む**。出勤予定より多くなる場合がある |

**GAS側での取得（getDailyAttendance関数）:**
```javascript
// 支援記録シートからその日の記録を取得
// A列（日時）が指定日と一致する行をすべて取得
const targetDate = formatDate(new Date(dateStr)); // yyyy-MM-dd形式
for (let i = 1; i < data.length; i++) {
  const rowDate = formatDate(new Date(data[i][0]));
  if (rowDate === targetDate) {
    attendances.push(parseAttendanceRow(data[i], i + 2));
  }
}
```

**Flutter側での計算:**
```dart
// quick_status_helper.dart
// attendances = GASから取得した出勤記録リスト
int checkedIn = attendances.length;
```

---

#### 3. 未出勤（notCheckedIn）

| 項目 | 内容 |
|------|------|
| 定義 | 出勤予定があるが、まだ出勤登録していない人数 |
| 参照元 | scheduledUsersのうち `hasCheckedIn=false` の人 |
| 特記事項 | 欠勤・事前連絡あり欠勤の記録がある人も「出勤登録していない」としてカウント |

**GAS側でのhasCheckedIn判定:**
```javascript
// 出勤予定者に対して、支援記録があるかチェック
let hasCheckedIn = false;
let attendance = null;
for (const att of dailyAttendances) {
  if (att.userName === userName) {
    hasCheckedIn = true;  // 支援記録の行が存在する
    attendance = att;
    break;
  }
}
// hasCheckedIn = true: 支援記録シートにその人の行がある
// hasCheckedIn = false: 支援記録シートにその人の行がない
```

**Flutter側での計算:**
```dart
// quick_status_helper.dart
int notCheckedIn = 0;
for (final user in scheduledUsers) {
  final hasCheckedIn = user['hasCheckedIn'] as bool? ?? false;
  if (!hasCheckedIn) {
    notCheckedIn++;  // 予定者で支援記録がない人をカウント
  }
}
```

---

#### 4. 記録未（notRegistered）

| 項目 | 内容 |
|------|------|
| 定義 | 支援記録（Z列：本人の状況）が未入力の人数 |
| 参照元 | 支援記録_YYYYシート Z列（index 25） |
| 判定方法 | `attendance.hasSupportRecord == false` |
| 特記事項 | **以下の3パターンすべてをカウント** |

**GAS側でのhasSupportRecord判定:**
```javascript
// Z列（index 25）に値があるかどうか
hasSupportRecord: !!row[25]
// row[25] = 「本人の状況」列の値
// 空文字・null・undefined → false
// 何か文字列がある → true
```

**Flutter側での計算（3パターン）:**
```dart
// quick_status_helper.dart
int notRegistered = 0;
final scheduledUserNames = <String>{};

// パターン1 & 2: 出勤予定者からカウント
for (final user in scheduledUsers) {
  final hasCheckedIn = user['hasCheckedIn'] as bool? ?? false;
  final attendance = user['attendance'] as Attendance?;
  final userName = user['userName'] as String? ?? '';

  scheduledUserNames.add(userName);  // 予定者の名前を記録

  if (hasCheckedIn) {
    // パターン1: 出勤済みでZ列未入力
    if (attendance != null && !attendance.hasSupportRecord) {
      notRegistered++;
    }
  } else {
    // パターン2: 欠勤系でZ列未入力
    if (attendance != null) {
      final status = attendance.attendanceStatus;
      final isAbsent = status == '欠勤' || status == '事前連絡あり欠勤';
      if (isAbsent && !attendance.hasSupportRecord) {
        notRegistered++;
      }
    }
  }
}

// パターン3: 予定外出勤者からカウント
for (final attendance in attendances) {
  final userName = attendance.userName ?? '';
  // 予定者に含まれない人（非利用日など）
  if (!scheduledUserNames.contains(userName)) {
    if (!attendance.hasSupportRecord) {
      notRegistered++;  // ステータス問わずカウント
    }
  }
}
```

### 記録未カウントの詳細ロジック

```
記録未カウント対象:

┌─────────────────────────────────────────────────────────────┐
│ パターン1: 出勤予定者で出勤済み                              │
│ ─────────────────────────────────────────────────────────── │
│ 条件: hasCheckedIn=true && hasSupportRecord=false           │
│ 例: 予定あり → 出勤登録済み → Z列未入力                      │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ パターン2: 出勤予定者で欠勤系                                │
│ ─────────────────────────────────────────────────────────── │
│ 条件: hasCheckedIn=false && (status=欠勤 or 事前連絡あり欠勤)│
│       && hasSupportRecord=false                              │
│ 例: 予定あり → 欠勤登録 → Z列未入力                          │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ パターン3: 予定外出勤者（非利用日など）                      │
│ ─────────────────────────────────────────────────────────── │
│ 条件: scheduledUserNamesに含まれない && hasSupportRecord=false│
│ 例: 非利用日だが出勤 → Z列未入力                             │
│ ※ステータス問わず（出勤/施設外/在宅/欠勤すべて対象）        │
└─────────────────────────────────────────────────────────────┘

カウント対象外:
- まだ出勤登録していない人（支援記録の行自体がない）
- Z列に何か入力されている人（hasSupportRecord=true）
```

### hasSupportRecord の判定

```javascript
// GAS側（gas_code_v4.js）での判定
hasSupportRecord: !!row[25]  // Z列（index 25）に値があるか

// Z列 = 「本人の状況」列
// 空文字・null・undefined → false
// 何か文字列がある → true
```

```dart
// Flutter側（attendance.dart）での判定
bool get hasSupportRecord {
  if (_hasSupportRecord != null) {
    return _hasSupportRecord!;  // GASから取得した値を優先
  }
  // フォールバック: userStatus（Z列の値）が空でないか
  return userStatus != null && userStatus!.isNotEmpty;
}
```

### データフロー

```
┌────────────────────────────────────────────────────────────────┐
│                        GAS API                                  │
├────────────────────────────────────────────────────────────────┤
│ getStaffDashboardBatch / getFacilityAdminDashboardBatch        │
│                                                                 │
│ 返却データ:                                                     │
│ {                                                               │
│   scheduledUsers: [                                             │
│     {                                                           │
│       userName: "山田太郎",                                     │
│       scheduledAttendance: "通所",                              │
│       hasCheckedIn: true,                                       │
│       attendance: { ... hasSupportRecord: false }               │
│     }                                                           │
│   ],                                                            │
│   dailyAttendances: [ Attendance objects ]                      │
│ }                                                               │
└────────────────────────────────────────────────────────────────┘
                              ↓
┌────────────────────────────────────────────────────────────────┐
│                    Flutter (共通ヘルパー)                       │
├────────────────────────────────────────────────────────────────┤
│ lib/utils/quick_status_helper.dart                             │
│                                                                 │
│ final quickStatus = calculateQuickStatus(                       │
│   scheduledUsers,   // GASから取得した出勤予定者リスト          │
│   attendances,      // GASから取得した出勤記録リスト            │
│ );                                                              │
│                                                                 │
│ // 結果                                                         │
│ quickStatus.scheduled      // 出勤予定                          │
│ quickStatus.checkedIn      // 出勤済                            │
│ quickStatus.notCheckedIn   // 未出勤                            │
│ quickStatus.notRegistered  // 記録未                            │
│ quickStatus.notRegisteredUsers // 記録未の利用者リスト          │
└────────────────────────────────────────────────────────────────┘
                              ↓
┌────────────────────────────────────────────────────────────────┐
│                      UI表示                                     │
├────────────────────────────────────────────────────────────────┤
│ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐           │
│ │ 出勤予定 │ │ 出勤済   │ │ 未出勤   │ │ 記録未   │           │
│ │   35名   │ │   38名   │ │    2名   │ │    5名   │           │
│ └──────────┘ └──────────┘ └──────────┘ └──────────┘           │
│                                         ↑タップで詳細表示       │
└────────────────────────────────────────────────────────────────┘
```

### 実装時の注意事項

1. **必ず共通ヘルパーを使用する**
   ```dart
   import '../../utils/quick_status_helper.dart';

   final quickStatus = calculateQuickStatus(scheduledUsers, attendances);
   ```

2. **別々にロジックを書かない**
   - 施設管理者画面と支援者画面で個別にカウントロジックを書くと、不一致の原因になる

3. **修正時はヘルパー関数を修正**
   - `quick_status_helper.dart`を修正すれば、両画面に自動反映される

4. **日付フォーマットに注意**
   - GAS側: `yyyy-MM-dd` 形式（`formatDate()`関数を使用）
   - Flutter側: `DateFormat('yyyy-MM-dd')` を使用

---

## 受給者証アラート

### 対象列（名簿_YYYYシート）
| 列 | インデックス | 内容 |
|----|-------------|------|
| AC列 | 27 | 支給決定期間有効期限 |
| AE列 | 29 | 適用期間有効期限 |

### 判定ロジック
- 上記の日付が今日以前（期限切れ）の場合にアラート表示
- 両方期限切れの場合は両方表示

---

## 詳細ドキュメント

- **実装状況一覧**: `claudedocs/IMPLEMENTATION_STATUS.md`
- **シート構成・プルダウン設定**: `claudedocs/PROJECT_SUMMARY.md`

---

## シート構成（詳細）

### 全権管理者シート - 施設マスタ
| 列 | 内容 | 備考 |
|----|------|------|
| A | 施設ID | 厚労省番号 |
| B | 施設名 | |
| C | 施設管理者名 | |
| D | 施設メールアドレス | |
| E | 管理者パスワード | 管理者個人のログイン用 |
| F | スプレッドシートID | |
| G | 年度 | |
| H | 作成日時 | |
| I | 更新日時 | |
| J | ステータス | |
| K | ChatWork APIキー | |
| L | ドライブフォルダID | |
| M | 施設住所 | |
| N | 施設電話番号 | |
| O | 契約開始日 | |
| P | 契約終了日 | |
| Q | 利用者定員 | |
| R | テンプレートID | |
| S | GAS URL | 現在の年度用 |
| T | 時間設定 | オン/オフ |
| U | 施設コード | 6桁数字、複数PC設定用 |
| V | 施設パスワード | 8桁英数字、複数PC設定用 |
| W | GAS URL 2026年度 | |
| X | GAS URL 2027年度 | |
| Y | GAS URL 2028年度 | |
| Z | GAS URL 2029年度 | |
| AA | GAS URL 2030年度 | |
| AB | GAS URL 2031年度 | |
| AC | GAS URL 2032年度 | |
| AD | GAS URL 2033年度 | |
| AE | GAS URL 2034年度 | |
| AF | GAS URL 2035年度 | |
| AG | GAS URL 2036年度 | |
| AH | GAS URL 2037年度 | |
| AI | GAS URL 2038年度 | |
| AJ | GAS URL 2039年度 | |

### 全権管理者シート - 全施設管理者（スーパー管理者）
| 列 | 内容 | 備考 |
|----|------|------|
| A | 管理者ID | |
| B | 管理者名 | |
| C | メールアドレス | |
| D | パスワード | |
| E | 権限レベル | 固定値: 0 |
| F | 作成日時 | |
| G | 更新日時 | |
| H | ステータス | |
| I | 備考 | |

### マスタ設定シート
- 利用者（8行目〜）: A:名前, B:フリガナ, C:契約状態, D〜J:曜日別予定
- 職員（8〜40行目）: V:名前, W:権限, X:メール, Y:パスワード, Z:職種, AA:資格, AB:配置, **AC:雇用形態, AD:退職日**
- プルダウン:
  - N8〜17(体調), O8〜17(睡眠), N31〜40(疲労), O31〜40(ストレス)
  - K44〜55(曜日予定)
  - **T44〜55(資格), U44〜55(職員配置), V44〜55(職種), W44〜55(勤務地), X44〜55(雇用形態)**
  - **AE30〜40(勤怠評価)**

### 支援記録_2025シート
| 列 | 内容 | 備考 |
|----|------|------|
| A | 日時 | yyyy-MM-dd形式 |
| B | 利用者名 | |
| C | 予定 | |
| D | 出欠（内容） | 出勤/欠勤/遅刻/早退/施設外/在宅/事前連絡あり欠勤 |
| E | AM業務 | |
| F | PM業務 | |
| G | 業務連絡 | |
| H | 体調 | |
| I | 睡眠 | |
| J | 出勤コメント | |
| K | 疲労 | |
| L | ストレス | |
| M | 退勤コメント | |
| N-O | 予備 | |
| P | 開始時刻 | |
| Q | 終了時刻 | |
| R | 昼休憩 | |
| S | 15分休憩 | |
| T | 他休憩 | |
| U | 実労時間 | |
| V | 食事 | |
| W | 欠席対応 | |
| X | 訪問 | |
| Y | 送迎 | |
| **Z** | **本人の状況** | **支援記録の判定に使用（hasSupportRecord）** |
| AA | 勤務地 | |
| AB | 記録者 | |
| AC | 予備 | |
| AD | 在宅評価 | |
| AE | 施設外評価 | |
| AF | 目標 | |
| AG | 勤務評価 | |
| AH | 就労評価 | |
| AI | 意欲 | |
| AJ | 通信対応 | |
| AK | 評価 | |
| AL | 感想 | |

### 名簿_2025シート
A:人数, B:氏名, C:カナ, D:年齢, E:ステータス, F:携帯, **G:ChatWorkルームID**, H:mail, I〜AQ:詳細情報, **AR:自社管理フラグ, AS:上限管理施設名, AT:上限管理施設番号**, AU〜BH:その他情報

**受給者証関連列:**
- AC列（index 27）: 支給決定期間有効期限
- AE列（index 29）: 適用期間有効期限
