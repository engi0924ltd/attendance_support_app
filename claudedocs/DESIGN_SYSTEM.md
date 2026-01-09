# 出勤支援アプリ デザインシステム

**最終更新**: 2026年1月9日

---

## デザインコンセプト

### V2: 「信頼感 × 温かみ × 効率性」

福祉施設向けアプリとして、以下の価値を表現するデザイン:

| 価値 | 表現方法 |
|------|----------|
| **信頼感** | 落ち着いた緑（成長・健康・安心を象徴） |
| **温かみ** | オレンジのアクセント（親しみやすさ） |
| **効率性** | 白ベース・クリーンなレイアウト（視認性重視） |

---

## カラーパレット

### プライマリカラー（緑系）

| 名称 | カラーコード | 用途 |
|------|-------------|------|
| Primary Green | `#2E7D32` | メインカラー、AppBar、ボタン |
| Primary Green Light | `#4CAF50` | ホバー、成功表示 |
| Primary Green Dark | `#1B5E20` | 強調、グラデーション |

### アクセントカラー（オレンジ系）

| 名称 | カラーコード | 用途 |
|------|-------------|------|
| Accent Orange | `#F57C00` | 注意喚起、アクション誘導 |
| Accent Orange Light | `#FFB74D` | 軽い警告、バッジ |

### 背景色

| 名称 | カラーコード | 用途 |
|------|-------------|------|
| Background White | `#FFFFFF` | カード背景 |
| Background Grey | `#F8F9FA` | 画面背景 |
| Surface Color | `#FFFFFF` | コンテンツ領域 |

### テキスト色

| 名称 | カラーコード | 用途 |
|------|-------------|------|
| Text Primary | `#1A1A1A` | 本文、見出し |
| Text Secondary | `#5F6368` | 補足テキスト |
| Text Hint | `#9E9E9E` | プレースホルダー |
| Text Light | `#FFFFFF` | ボタン上のテキスト |

### ステータスカラー

| 名称 | カラーコード | 用途 |
|------|-------------|------|
| Success | `#4CAF50` | 成功、完了 |
| Warning | `#FFA726` | 警告 |
| Error | `#E53935` | エラー、削除 |
| Info | `#2196F3` | 情報、ヘルプ |

### ボーダー・区切り線

| 名称 | カラーコード | 用途 |
|------|-------------|------|
| Border Color | `#E0E0E0` | カード枠線 |
| Divider Color | `#EEEEEE` | リスト区切り |

---

## タイポグラフィ

### 見出し

| スタイル | サイズ | ウェイト | 用途 |
|----------|--------|----------|------|
| Headline Large | 28px | Bold | ページタイトル |
| Headline Medium | 24px | Bold | セクションタイトル |
| Headline Small | 20px | SemiBold | カードタイトル |

### タイトル

| スタイル | サイズ | ウェイト | 用途 |
|----------|--------|----------|------|
| Title Large | 18px | SemiBold | サブセクション |
| Title Medium | 16px | SemiBold | リストタイトル |

### 本文

| スタイル | サイズ | ウェイト | 用途 |
|----------|--------|----------|------|
| Body Large | 16px | Normal | メイン本文 |
| Body Medium | 14px | Normal | 補足テキスト |

### ラベル

| スタイル | サイズ | ウェイト | 用途 |
|----------|--------|----------|------|
| Label Large | 14px | Medium | ボタンラベル |
| Label Medium | 12px | Medium | タグ、バッジ |

---

## コンポーネント

### CleanScaffold
白背景のベースScaffold。すべての画面で使用。

```dart
CleanScaffold(
  appBar: CleanAppBar(title: 'タイトル'),
  body: /* コンテンツ */,
)
```

### CleanAppBar
緑のソリッドカラーAppBar。

```dart
CleanAppBar(
  title: 'タイトル',
  showBackButton: true,
  actions: [/* アクションボタン */],
)
```

### CleanCard
ボーダー付きの白カード。

```dart
CleanCard(
  padding: EdgeInsets.all(16),
  child: /* コンテンツ */,
  onTap: () {},  // オプション
)
```

### PrimaryButton
緑のメインボタン。

```dart
PrimaryButton(
  label: 'ボタン',
  icon: Icons.check,
  onPressed: () {},
  isLoading: false,
)
```

### SecondaryButton
アウトラインのサブボタン。

```dart
SecondaryButton(
  label: 'キャンセル',
  onPressed: () {},
)
```

### SectionHeader
セクション見出し。

```dart
SectionHeader(
  title: 'セクション名',
  icon: Icons.settings,
  trailing: /* オプションウィジェット */,
)
```

### StatCard
統計表示カード。

```dart
StatCard(
  label: '出勤者数',
  value: '15',
  unit: '名',
  icon: Icons.people,
  iconColor: AppThemeV2.primaryGreen,
)
```

---

## レイアウト規則

### スペーシング

| 用途 | サイズ |
|------|--------|
| 画面パディング | 20px |
| カード間マージン | 12px |
| セクション間 | 24-28px |
| 要素間（小） | 8px |
| 要素間（中） | 12px |
| 要素間（大） | 16px |

### 角丸

| 用途 | サイズ |
|------|--------|
| カード | 12px |
| ボタン | 8px |
| 入力フィールド | 8px |
| バッジ | 20px（pill形状） |
| アイコン背景 | 10-14px |

### 影

```dart
// カード用（軽い影）
BoxShadow(
  color: Colors.black.withOpacity(0.04),
  blurRadius: 8,
  offset: Offset(0, 2),
)

// メニューカード用（やや強調）
BoxShadow(
  color: Colors.black.withOpacity(0.03),
  blurRadius: 6,
  offset: Offset(0, 2),
)
```

---

## 画面別ガイドライン

### 利用者向け画面（user/）
- タピルイラストを使用（checkin, checkout, select）
- 大きめのボタン・テキストで操作しやすく
- シンプルな導線

### 支援者向け画面（staff/）
- 情報密度を適度に
- 一覧→詳細の階層構造
- 素早い入力を重視

### 施設管理者向け画面（facility_admin/）
- ダッシュボードでステータス一覧
- 管理機能へのアクセス性
- 統計・分析の可視化

### 全権管理者向け画面（superadmin/）
- 施設一覧の管理
- セットアップウィザード
- シンプルな管理画面

---

## 使用ファイル

| ファイル | 用途 |
|---------|------|
| `lib/theme/app_theme_v2.dart` | V2テーマ定義・コンポーネント |
| `lib/theme/app_theme.dart` | V1テーマ（レガシー、参照用） |

---

## 画像アセット

### 利用者画面用イラスト

| ファイル | 用途 |
|---------|------|
| `assets/images/tapir_select_name.png` | 利用者選択画面 |
| `assets/images/tapir_checkin_success.png` | 出勤完了画面 |
| `assets/images/tapir_checkout_success.png` | 退勤完了画面 |

---

## バージョン履歴

| バージョン | 日付 | 変更内容 |
|-----------|------|----------|
| V2 | 2026-01-09 | プロフェッショナルデザインに統一 |
| V1 | - | ポップなグラデーションデザイン（レガシー） |
