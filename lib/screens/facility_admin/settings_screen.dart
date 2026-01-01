import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/fiscal_year_service.dart';
import 'fiscal_year_setup_wizard_screen.dart';

/// 施設管理者設定画面
class FacilityAdminSettingsScreen extends StatefulWidget {
  final String? gasUrl;
  final String? facilityId;

  const FacilityAdminSettingsScreen({
    super.key,
    this.gasUrl,
    this.facilityId,
  });

  @override
  State<FacilityAdminSettingsScreen> createState() =>
      _FacilityAdminSettingsScreenState();
}

class _FacilityAdminSettingsScreenState
    extends State<FacilityAdminSettingsScreen> {
  late FiscalYearService _fiscalYearService;
  bool _isLoading = true;
  bool _isCreating = false;
  String? _errorMessage;

  int? _activeYear; // 現在操作中のスプレッドシートの年度
  int? _currentFiscalYear; // システム上の現在年度（4月始まり）
  List<Map<String, dynamic>> _yearSpreadsheets = [];

  @override
  void initState() {
    super.initState();
    _fiscalYearService = FiscalYearService(facilityGasUrl: widget.gasUrl);
    _loadFiscalYearInfo();
  }

  Future<void> _loadFiscalYearInfo() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _fiscalYearService.getAvailableFiscalYears();

      setState(() {
        _yearSpreadsheets = (data['yearSpreadsheets'] as List<dynamic>?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            [];
        _currentFiscalYear = data['currentFiscalYear'] as int?;
        _activeYear = data['activeYear'] as int?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _createNextFiscalYear() async {
    if (_activeYear == null) return;

    final nextYear = _activeYear! + 1;

    // 確認ダイアログ
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('次年度スプレッドシート作成'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$nextYear年度のスプレッドシートを新規作成します。'),
            const SizedBox(height: 16),
            const Text('以下の処理が実行されます：'),
            const SizedBox(height: 8),
            const Text('1. 施設フォルダに新しいファイルを作成'),
            const Text('2. シート構造をコピー'),
            const Text('3. 契約中利用者の情報をコピー'),
            const Text('4. 支援記録データはクリア'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '新しいスプレッドシートは施設フォルダ内に作成されます',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('作成する'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    try {
      final result =
          await _fiscalYearService.createNextFiscalYear(_activeYear!);

      if (mounted) {
        final copiedCount = result['copiedUsersCount'] ?? 0;
        final newSpreadsheet = result['newSpreadsheet'] as Map<String, dynamic>?;
        final createdYear = result['nextYear'] ?? nextYear;

        // GASセットアップウィザード画面に遷移
        if (newSpreadsheet != null && widget.facilityId != null) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FiscalYearSetupWizardScreen(
                nextYear: createdYear,
                spreadsheetId: newSpreadsheet['id'] ?? '',
                spreadsheetName: newSpreadsheet['name'] ?? '',
                spreadsheetUrl: newSpreadsheet['url'] ?? '',
                copiedUsersCount: copiedCount,
                facilityId: widget.facilityId!,
              ),
            ),
          );
        } else {
          // フォールバック：シンプルなダイアログ表示
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text('作成完了'),
                ],
              ),
              content: Text('$createdYear年度のスプレッドシートを作成しました。\n'
                  'コピーした利用者数: $copiedCount人'),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }

        // 情報を再読み込み
        await _loadFiscalYearInfo();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  Future<void> _switchToYear(Map<String, dynamic> yearInfo) async {
    final year = yearInfo['year'] as int;
    final spreadsheetId = yearInfo['spreadsheetId'] as String;

    // 確認ダイアログ
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('年度切り替え'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$year年度に切り替えますか？'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '年度を切り替えるには、対応するGAS URLが必要です。\n'
                      '新年度のスプレッドシートにGASをデプロイしてURLを更新してください。',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('切り替える'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // 年度情報を保存
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('current_fiscal_year', year);
    await prefs.setString('current_spreadsheet_id', spreadsheetId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$year年度に切り替えました（GAS URLの更新が必要です）'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadFiscalYearInfo,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // エラーメッセージ
                    if (_errorMessage != null)
                      Card(
                        color: Colors.red.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              const Icon(Icons.error, color: Colors.red),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // 年度管理セクション
                    const Text(
                      '年度管理',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 現在の操作年度
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, color: Colors.blue),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '現在操作中の年度',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  '${_activeYear ?? "-"}年度',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 利用可能な年度一覧
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.folder, color: Colors.amber),
                                SizedBox(width: 8),
                                Text(
                                  '施設フォルダ内のスプレッドシート',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_yearSpreadsheets.isEmpty)
                              const Text('スプレッドシートが見つかりません')
                            else
                              ..._yearSpreadsheets.map((yearInfo) {
                                final year = yearInfo['year'] as int;
                                final isActive = year == _activeYear;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: isActive
                                          ? Colors.blue
                                          : Colors.grey.shade300,
                                      width: isActive ? 2 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    color: isActive
                                        ? Colors.blue.shade50
                                        : null,
                                  ),
                                  child: ListTile(
                                    leading: Icon(
                                      Icons.table_chart,
                                      color: isActive
                                          ? Colors.blue
                                          : Colors.grey,
                                    ),
                                    title: Text(
                                      '$year年度',
                                      style: TextStyle(
                                        fontWeight: isActive
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                    subtitle: Text(
                                      yearInfo['name'] ?? '',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    trailing: isActive
                                        ? const Chip(
                                            label: Text(
                                              '使用中',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.white,
                                              ),
                                            ),
                                            backgroundColor: Colors.blue,
                                          )
                                        : TextButton(
                                            onPressed: () =>
                                                _switchToYear(yearInfo),
                                            child: const Text('切替'),
                                          ),
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 次年度作成ボタン
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.add_circle, color: Colors.green),
                                SizedBox(width: 8),
                                Text(
                                  '次年度更新',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _activeYear != null
                                  ? '${_activeYear! + 1}年度のスプレッドシートを新規作成します。\n'
                                      '契約中の利用者情報が新しい年度にコピーされます。'
                                  : '年度情報を取得できませんでした。',
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed:
                                    _isCreating || _activeYear == null
                                        ? null
                                        : _createNextFiscalYear,
                                icon: _isCreating
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.create_new_folder),
                                label: Text(_isCreating
                                    ? '作成中...'
                                    : '次年度スプレッドシートを作成'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 注意事項
                    Card(
                      color: Colors.grey.shade100,
                      child: const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.grey),
                                SizedBox(width: 8),
                                Text(
                                  '年度切り替えの手順',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Text(
                              '1. 「次年度スプレッドシートを作成」で新しいファイルを作成\n'
                              '2. Google Apps Scriptエディタで新しいスプレッドシートを開く\n'
                              '3. GASコードをデプロイしてURLを取得\n'
                              '4. 全権管理者画面で施設のGAS URLを更新',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
