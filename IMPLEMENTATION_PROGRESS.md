# 利用者管理機能拡張 - 実装進捗メモ

## 📋 プロジェクト概要

B型施設の支援者サポートアプリに、詳細な利用者管理機能（名簿_2025シート連携）を追加する実装作業。

### 目標
- 利用者登録時に「マスタ設定」タブと「名簿_2025」タブの両方に書き込む
- 名簿_2025には60列の詳細情報を管理
- アプリから全情報を入力可能にする（必須項目と任意項目を設定）
- プルダウン選択肢はマスタ設定シートから動的取得

---

## ✅ 完了済みの作業

### 1. GAS側の基盤実装（完了）

#### 1.1 名簿_2025シートの設定追加
**ファイル**: `/Users/yamaguchisatoshi/Desktop/attendance_support_app/assets/gas/gas_code_v2.js`

```javascript
const SHEET_NAMES = {
  MASTER: 'マスタ設定',
  ATTENDANCE: '勤怠_2025',
  SUPPORT: '支援記録_2025',
  ROSTER: '名簿_2025'  // ← 追加
};
```

#### 1.2 名簿_2025の列定義（全60列）
**ファイル**: `gas_code_v2.js` (120-201行目)

```javascript
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
  // ... 全60列の定義（詳細は gas_code_v2.js 参照）
};
```

#### 1.3 名簿用プルダウン選択肢の設定
**場所**: マスタ設定シート L〜S列、44〜50行目

```javascript
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
```

#### 1.4 プルダウン取得APIの拡張
**関数**: `handleGetDropdowns()` (308-337行目)

名簿用プルダウンを追加：
- `rosterStatus`
- `lifeProtection`
- `disabilityPension`
- `disabilityGrade`
- `disabilityType`
- `supportLevel`
- `contractType`
- `employmentSupport`

#### 1.5 名簿シート操作のヘルパー関数
**関数**: `writeToRosterSheet()`, `deleteFromRosterSheet()` (667-763行目)

- 全60列のデータを名簿_2025シートに書き込む関数
- 利用者名で検索して該当行を削除する関数

---

## ⏳ 現在の状態（未完了）

### GAS側の残作業

以下の3つの関数を修正して、名簿_2025シートにも書き込むようにする必要があります：

#### 2.1 `handleCreateUser()` の修正が必要
**現在の状態**: マスタ設定シートのみに書き込み
**必要な修正**: 名簿_2025シートにも同時に書き込む

**修正箇所**: 820-897行目付近
```javascript
function handleCreateUser(data) {
  // ... 既存のバリデーションとマスタ設定への書き込み ...

  // ★追加が必要★
  // 名簿_2025シートにも書き込む
  const rosterSheet = getSheet(SHEET_NAMES.ROSTER);
  // 空行を探す（名簿シートの3行目から）
  let rosterRow = 3;
  const rosterLastRow = rosterSheet.getLastRow();
  for (let row = 3; row <= rosterLastRow; row++) {
    const existingName = rosterSheet.getRange(row, ROSTER_COLS.NAME).getValue();
    if (!existingName || existingName === '') {
      rosterRow = row;
      break;
    }
  }
  if (rosterRow === 3 && rosterSheet.getRange(3, ROSTER_COLS.NAME).getValue()) {
    rosterRow = rosterLastRow + 1;
  }

  writeToRosterSheet(rosterSheet, rosterRow, data);

  return createSuccessResponse({ ... });
}
```

#### 2.2 `handleUpdateUser()` の修正が必要
**現在の状態**: マスタ設定シートのみ更新
**必要な修正**: 名簿_2025シートも同時に更新

**修正箇所**: 902-965行目付近（行番号はファイル変更で異なる可能性あり）
```javascript
function handleUpdateUser(data) {
  // ... 既存のバリデーションとマスタ設定の更新 ...

  // ★追加が必要★
  // 名簿_2025シートも更新（利用者名で検索）
  const rosterSheet = getSheet(SHEET_NAMES.ROSTER);
  const rosterLastRow = rosterSheet.getLastRow();
  for (let row = 3; row <= rosterLastRow; row++) {
    const rosterName = rosterSheet.getRange(row, ROSTER_COLS.NAME).getValue();
    if (rosterName === data.name) {
      writeToRosterSheet(rosterSheet, row, data);
      break;
    }
  }

  return createSuccessResponse({ ... });
}
```

#### 2.3 `handleDeleteUser()` の修正が必要
**現在の状態**: マスタ設定シートのみ削除
**必要な修正**: 名簿_2025シートからも削除

**修正箇所**: 970行目付近
```javascript
function handleDeleteUser(data) {
  // ... 既存のバリデーション ...

  const sheet = getSheet(SHEET_NAMES.MASTER);

  // 利用者名を取得してから削除
  const userName = sheet.getRange(data.rowNumber, MASTER_CONFIG.USER_COLS.NAME).getValue();

  // マスタ設定のA-J列のデータをクリア（既存処理）
  // ...

  // ★追加が必要★
  // 名簿_2025シートからも削除
  const rosterSheet = getSheet(SHEET_NAMES.ROSTER);
  deleteFromRosterSheet(rosterSheet, userName);

  return createSuccessResponse({ message: '利用者を削除しました' });
}
```

---

## 📝 次のセッションでやること

### Phase 1: GAS側の完成（優先度: 🔴 高）

1. **`handleCreateUser()` の修正**
   - 名簿_2025シートへの書き込み処理を追加
   - 空行検索ロジックの実装

2. **`handleUpdateUser()` の修正**
   - 名簿_2025シートの更新処理を追加
   - 利用者名での行検索ロジックの実装

3. **`handleDeleteUser()` の修正**
   - 名簿_2025シートからの削除処理を追加

4. **GASコードのデプロイと動作確認**
   - Google Apps Scriptにコピー
   - 新しいバージョンとしてデプロイ
   - プルダウン取得APIが正しく動作するか確認

### Phase 2: Flutter Userモデルの拡張（優先度: 🔴 高）

**ファイル**: `/Users/yamaguchisatoshi/Desktop/attendance_support_app/lib/models/user.dart`

現在のUserモデルは以下のフィールドのみ：
```dart
class User {
  final String name;
  final String furigana;
  final String status;
  final String? scheduledMon;  // 〜 scheduledSun
  final int? rowNumber;
}
```

**拡張が必要**: 全60列に対応するフィールドを追加

#### 追加するフィールド例
```dart
class User {
  // 既存フィールド
  final String name;
  final String furigana;
  final String status;

  // 連絡先情報
  final String? mobilePhone;
  final String? chatworkId;
  final String? mail;
  final String? emergencyContact1;
  final String? emergencyPhone1;
  final String? emergencyContact2;
  final String? emergencyPhone2;

  // 住所情報
  final String? postalCode;
  final String? prefecture;      // 必須
  final String? city;            // 必須
  final String? ward;            // 必須
  final String? address;         // 必須
  final String? address2;

  // 詳細情報
  final String? birthDate;
  final String? lifeProtection;
  final String? disabilityPension;
  final String? disabilityNumber;
  final String? disabilityGrade;
  final String? disabilityType;
  final String? handbookValid;
  final String? municipalNumber;
  final String? certificateNumber;
  final String? decisionPeriod1;
  final String? decisionPeriod2;
  final String? applicableStart;
  final String? applicableEnd;
  final String? supplyAmount;
  final String? supportLevel;
  final String? useStartDate;    // 必須

  // 期間計算
  final String? initialAddition;

  // 相談支援事業所
  final String? consultationFacility;
  final String? consultationStaff;
  final String? consultationContact;

  // グループホーム
  final String? ghFacility;
  final String? ghStaff;
  final String? ghContact;

  // その他関係機関
  final String? otherFacility;
  final String? otherStaff;
  final String? otherContact;

  // 工賃振込先情報
  final String? bankName;
  final String? bankCode;
  final String? branchName;
  final String? branchCode;
  final String? accountNumber;

  // 退所・就労情報
  final String? leaveDate;
  final String? leaveReason;
  final String? workName;
  final String? workContact;
  final String? workContent;
  final String? contractType;
  final String? employmentSupport;
  final String? notes;

  // 曜日別出欠予定（マスタ設定用）
  final String? scheduledMon;
  final String? scheduledTue;
  final String? scheduledWed;
  final String? scheduledThu;
  final String? scheduledFri;
  final String? scheduledSat;
  final String? scheduledSun;

  final int? rowNumber;

  User({
    required this.name,
    required this.furigana,
    required this.status,
    this.mobilePhone,
    // ... 全フィールド
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // 全フィールドのマッピング
  }

  Map<String, dynamic> toJson() {
    // 全フィールドのマッピング
  }

  User copyWith({
    // 全フィールド対応
  });
}
```

### Phase 3: Flutter UserFormScreenの大幅改修（優先度: 🟡 中）

**ファイル**: `/Users/yamaguchisatoshi/Desktop/attendance_support_app/lib/screens/facility_admin/user_form_screen.dart`

#### 現在の仕様
- シンプルな縦スクロール型フォーム
- 基本情報と曜日別予定のみ

#### 新しい仕様（タブ形式）
**使用Widget**: `TabBarView` + `TabController`

```dart
class UserFormScreen extends StatefulWidget {
  // ...
}

class _UserFormScreenState extends State<UserFormScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 全フィールド用のコントローラー（60個以上）
  late TextEditingController _nameController;
  late TextEditingController _furiganaController;
  // ... 全フィールド分

  // 退所日の監視用
  bool _showRetirementInfo = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);

    // 全コントローラーの初期化
    _nameController = TextEditingController(text: widget.user?.name ?? '');
    // ...

    // 退所日の監視
    _leaveDateController.addListener(() {
      setState(() {
        _showRetirementInfo = _leaveDateController.text.isNotEmpty;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? '利用者情報編集' : '利用者登録'),
        backgroundColor: Colors.purple,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: '基本情報'),
            Tab(text: '連絡先情報'),
            Tab(text: '受給者証情報'),
            Tab(text: '銀行口座情報'),
            Tab(text: 'その他情報'),
            Tab(text: '退所・就労情報'),  // 条件付き表示
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBasicInfoTab(),
          _buildContactInfoTab(),
          _buildCertificateInfoTab(),
          _buildBankInfoTab(),
          _buildOtherInfoTab(),
          _buildRetirementInfoTab(),
        ],
      ),
      bottomNavigationBar: _buildSubmitButton(),
    );
  }
}
```

#### セクション別フィールド

**1. 基本情報タブ** (必須項目多め)
- 氏名 ✅必須
- 氏名カナ ✅必須
- ステータス ✅必須
- 都道府県 ✅必須
- 市区町村 ✅必須
- 政令指定都市区名 ✅必須
- 住所 ✅必須
- 利用開始日 ✅必須
- 郵便番号（任意）
- 住所2（任意）
- 生年月日（任意）
- 曜日別出欠予定（月〜日、任意）

**2. 連絡先情報タブ** (全て任意)
- 携帯電話番号
- ChatWorkルームID
- mail
- 緊急連絡先 - 連絡先
- 緊急連絡先 - 電話番号
- 緊急連絡先2 - 連絡先
- 緊急連絡先2 - 電話番号

**3. 受給者証情報タブ** (全て任意)
- 生活保護（プルダウン）
- 障がい者手帳年金（プルダウン）
- 障害者手帳番号
- 障害等級（プルダウン）
- 障害種別（プルダウン）
- 手帳有効期間
- 市区町村番号
- 受給者証番号等
- 支給決定期間（2つ）
- 適用期間開始日
- 適用期間有効期限
- 支給量（プルダウン）
- 障害支援区分（プルダウン）

**4. 銀行口座情報タブ** (全て任意)
- 銀行名
- 金融機関コード
- 支店名
- 支店番号
- 口座番号

**5. その他情報タブ** (全て任意)
- 相談支援事業所 - 施設名
- 相談支援事業所 - 担当者名
- 相談支援事業所 - 連絡先
- グループホーム - 施設名
- グループホーム - 担当者名
- グループホーム - 連絡先
- ○○○○ - 施設名
- ○○○○ - 担当者名
- ○○○○ - 連絡先

**6. 退所・就労情報タブ** (条件付き表示)
- 退所日 → 入力すると以下が表示される
- 退所理由
- 勤務先 名称
- 勤務先 連絡先
- 業務内容
- 契約形態（プルダウン）
- 定着支援 有無（プルダウン）
- 配慮事項

### Phase 4: Flutter UserServiceの拡張（優先度: 🟡 中）

**ファイル**: `/Users/yamaguchisatoshi/Desktop/attendance_support_app/lib/services/user_service.dart`

`createUser()` と `updateUser()` メソッドに全60フィールドのパラメータを追加。

```dart
Future<Map<String, dynamic>> createUser({
  required String name,
  required String furigana,
  required String status,
  String? scheduledMon,
  // ... 既存の曜日別予定 ...

  // ★追加が必要★
  String? mobilePhone,
  String? chatworkId,
  String? mail,
  // ... 全60フィールド分のパラメータ ...
}) async {
  final body = jsonEncode({
    'action': 'user/create',
    'name': name,
    'furigana': furigana,
    'status': status,
    'scheduledMon': scheduledMon ?? '',
    // ... 全フィールド ...
    'mobilePhone': mobilePhone ?? '',
    'chatworkId': chatworkId ?? '',
    // ... 全60フィールド分 ...
  });

  // ... 既存のPOST処理 ...
}
```

### Phase 5: 動作確認とデバッグ（優先度: 🔴 高）

1. GASコードのデプロイ確認
2. プルダウン選択肢の取得確認
3. 利用者登録時に両シートに書き込まれるか確認
4. 利用者更新時に両シートが更新されるか確認
5. 利用者削除時に両シートから削除されるか確認
6. タブ切り替えの動作確認
7. 退所日入力時の条件付き表示確認
8. 必須項目のバリデーション確認

---

## 🗂️ 重要なファイルパス

### GAS側
- **メインコード**: `/Users/yamaguchisatoshi/Desktop/attendance_support_app/assets/gas/gas_code_v2.js`
  - 修正箇所: `handleCreateUser()`, `handleUpdateUser()`, `handleDeleteUser()`

### Flutter側
- **Userモデル**: `/Users/yamaguchisatoshi/Desktop/attendance_support_app/lib/models/user.dart`
- **UserFormScreen**: `/Users/yamaguchisatoshi/Desktop/attendance_support_app/lib/screens/facility_admin/user_form_screen.dart`
- **UserListScreen**: `/Users/yamaguchisatoshi/Desktop/attendance_support_app/lib/screens/facility_admin/user_list_screen.dart`
- **UserService**: `/Users/yamaguchisatoshi/Desktop/attendance_support_app/lib/services/user_service.dart`

---

## 📊 名簿_2025シートの列構成（完全版）

### A〜H列（基本情報）
| 列 | 項目名 | 入力種別 | 必須 |
|----|--------|---------|------|
| A | 人数 | 自動 | - |
| B | 氏名 | 緑（自由） | ✅ |
| C | 氏名カナ | 緑（自由） | ✅ |
| D | 年齢 | 青（自動計算） | - |
| E | ステータス | オレンジ（プルダウン） | ✅ |
| F | 携帯電話番号 | 緑（自由） | - |
| G | ChatWorkルームID | 緑（自由） | - |
| H | mail | 緑（自由） | - |

### I〜L列（緊急連絡先）
| 列 | 項目名 | 入力種別 |
|----|--------|---------|
| I | 緊急連絡先 - 連絡先 | 緑（自由） |
| J | 緊急連絡先 - 電話番号 | 緑（自由） |
| K | 緊急連絡先2 - 連絡先 | 緑（自由） |
| L | 緊急連絡先2 - 電話番号 | 緑（自由） |

### M〜R列（住所情報）
| 列 | 項目名 | 入力種別 | 必須 |
|----|--------|---------|------|
| M | 郵便番号 | 緑（自由） | - |
| N | 都道府県 | 緑（自由） | ✅ |
| O | 市区町村 | 緑（自由） | ✅ |
| P | 政令指定都市区名入力 | 緑（自由） | ✅ |
| Q | 住所 | 緑（自由） | ✅ |
| R | 住所2（転居先など） | 緑（自由） | - |

### S〜AH列（福祉・障害情報）
| 列 | 項目名 | 入力種別 | 必須 |
|----|--------|---------|------|
| S | 生年月日（西暦） | 緑（自由） | - |
| T | 生活保護 | オレンジ（プルダウン） | - |
| U | 障がい者手帳年金 | オレンジ（プルダウン） | - |
| V | 障害者手帳番号 | 緑（自由） | - |
| W | 障害等級 | オレンジ（プルダウン） | - |
| X | 障害種別 | オレンジ（プルダウン） | - |
| Y | 手帳有効期間 | 緑（自由） | - |
| Z | 市区町村番号 | 緑（自由） | - |
| AA | 受給者証番号等 | 緑（自由） | - |
| AB | 支給決定期間 | 緑（自由） | - |
| AC | 支給決定期間 | 緑（自由） | - |
| AD | 適用期間開始日 | 緑（自由） | - |
| AE | 適用期間有効期限 | 緑（自由） | - |
| AF | 支給量 | オレンジ（プルダウン） | - |
| AG | 障害支援区分 | オレンジ（プルダウン） | - |
| AH | 利用開始日 | 緑（自由） | ✅ |

### AI〜AK列（期間計算）
| 列 | 項目名 | 入力種別 |
|----|--------|---------|
| AI | 本日までの利用期間 | 青（自動計算） |
| AJ | 初期加算有効期間（30日） | 緑（自由） |
| AK | 個別支援計画書更新日 | 青（自動計算） |

### AL〜AT列（関係機関情報）
| 列 | 項目名 |
|----|--------|
| AL | 相談支援事業所 - 施設名 |
| AM | 相談支援事業所 - 担当者名 |
| AN | 相談支援事業所 - 連絡先 |
| AO | グループホーム - 施設名 |
| AP | グループホーム - 担当者名 |
| AQ | グループホーム - 連絡先 |
| AR | ○○○○ - 施設名 |
| AS | ○○○○ - 担当者名 |
| AT | ○○○○ - 連絡先 |

### AU〜AY列（工賃振込先情報）
| 列 | 項目名 |
|----|--------|
| AU | 銀行名 |
| AV | 金融機関コード |
| AW | 支店名 |
| AX | 支店番号 |
| AY | 口座番号 |

### AZ〜BH列（退所・就労情報）
| 列 | 項目名 | 入力種別 |
|----|--------|---------|
| AZ | （空白列） | - |
| BA | 退所日 | 緑（自由） |
| BB | 退所理由 | 緑（自由） |
| BC | 勤務先 名称 | 緑（自由） |
| BD | 勤務先 連絡先 | 緑（自由） |
| BE | 業務内容 | 緑（自由） |
| BF | 契約形態 | オレンジ（プルダウン） |
| BG | 定着支援 有無 | オレンジ（プルダウン） |
| BH | 配慮事項 | 緑（自由） |

---

## 🎯 重要な技術的ポイント

### 1. データ同期の仕組み
- **マスタ設定タブ**: 勤怠システムで使用（シンプル・高速）
  - A〜J列: 氏名、フリガナ、ステータス、曜日別出欠予定
- **名簿_2025タブ**: 詳細な利用者情報管理（詳細・完全）
  - A〜BH列: 全60列の詳細情報

### 2. プルダウン選択肢の取得
- マスタ設定シート L〜S列、44〜50行目から動的取得
- `handleGetDropdowns()` APIで一括取得
- Flutter側でキャッシュして高速化

### 3. 退所日の条件付き表示
```dart
// 退所日コントローラーの監視
_leaveDateController.addListener(() {
  setState(() {
    _showRetirementInfo = _leaveDateController.text.isNotEmpty;
  });
});

// UI側での条件表示
if (_showRetirementInfo) {
  // 退所理由、勤務先情報などを表示
}
```

### 4. 名簿シートへの書き込みタイミング
- **新規登録時**: マスタ設定 → 名簿_2025 の順に書き込み
- **更新時**: マスタ設定 → 名簿_2025（利用者名で検索）の順に更新
- **削除時**: マスタ設定 → 名簿_2025（利用者名で検索）の順に削除

---

## 🚨 注意事項

1. **文字エンコーディング**: 過去にUTF-8エンコーディング問題が発生したため、ファイル作成時は既存ファイルのコピー＆編集を推奨

2. **パフォーマンス最適化**:
   - マスタ設定シート: 200行まで走査
   - 勤怠・支援記録シート: 逆順走査で高速化（50,000行対応）

3. **必須項目のバリデーション**:
   - 氏名、氏名カナ、ステータス
   - 都道府県、市区町村、政令指定都市区名、住所
   - 利用開始日

4. **GASデプロイ手順**:
   - 「拡張機能」→「Apps Script」
   - コード全体をコピー＆貼り付け
   - 「デプロイ」→「デプロイを管理」→「新しいバージョン」

---

## 📞 次のセッション開始時の確認事項

1. TodoListの確認（このメモと照合）
2. GAS側の3つの関数修正から開始
3. 修正完了後、GASデプロイして動作確認
4. 問題なければFlutter側の実装へ

---

**最終更新**: 2025-12-14
**作成者**: Claude Code
**次回作業開始**: Phase 1 - GAS側の完成から
