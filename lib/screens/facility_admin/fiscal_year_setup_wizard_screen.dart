import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/fiscal_year_service.dart';

/// 次年度GASセットアップウィザード画面
class FiscalYearSetupWizardScreen extends StatefulWidget {
  final int nextYear;
  final String spreadsheetId;
  final String spreadsheetName;
  final String spreadsheetUrl;
  final int copiedUsersCount;
  final String facilityId;

  const FiscalYearSetupWizardScreen({
    super.key,
    required this.nextYear,
    required this.spreadsheetId,
    required this.spreadsheetName,
    required this.spreadsheetUrl,
    required this.copiedUsersCount,
    required this.facilityId,
  });

  @override
  State<FiscalYearSetupWizardScreen> createState() =>
      _FiscalYearSetupWizardScreenState();
}

class _FiscalYearSetupWizardScreenState
    extends State<FiscalYearSetupWizardScreen> {
  bool _isGasCodeCopied = false;
  bool _isSpreadsheetOpened = false;
  bool _showInstructions = false;
  bool _isUrlRegistered = false;
  bool _isRegistering = false;

  final TextEditingController _gasUrlController = TextEditingController();
  final MasterGasService _masterGasService = MasterGasService();

  @override
  void dispose() {
    _gasUrlController.dispose();
    super.dispose();
  }

  /// GASコードをクリップボードにコピー
  Future<void> _copyGasCode() async {
    try {
      final gasCode =
          await rootBundle.loadString('assets/gas/gas_code_v4.js');

      await Clipboard.setData(ClipboardData(text: gasCode));

      setState(() {
        _isGasCodeCopied = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('GASコードをクリップボードにコピーしました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('GASコードの読み込みに失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// スプレッドシートを開く
  Future<void> _openSpreadsheet() async {
    final url = Uri.parse(widget.spreadsheetUrl);

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      setState(() {
        _isSpreadsheetOpened = true;
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('スプレッドシートを開けませんでした')),
        );
      }
    }
  }

  /// GAS URLを登録
  Future<void> _registerGasUrl() async {
    final gasUrl = _gasUrlController.text.trim();

    // バリデーション
    if (gasUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GAS URLを入力してください'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!gasUrl.startsWith('https://script.google.com/macros/')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('正しいGoogle Apps ScriptのURLを入力してください'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isRegistering = true;
    });

    try {
      await _masterGasService.registerYearGasUrl(
        facilityId: widget.facilityId,
        fiscalYear: widget.nextYear,
        gasUrl: gasUrl,
        setAsActive: false, // 登録のみ、アクティブにはしない
      );

      setState(() {
        _isUrlRegistered = true;
        _isRegistering = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.nextYear}年度のGAS URLを登録しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isRegistering = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('登録エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.nextYear}年度 GASセットアップ'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ヘッダー
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: Colors.green, size: 32),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${widget.nextYear}年度スプレッドシート作成完了',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('ファイル名: ${widget.spreadsheetName}'),
                    Text('コピーした利用者数: ${widget.copiedUsersCount}人'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info, color: Colors.orange),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '新年度で利用するには、以下の手順でGASをセットアップしてください。',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ステップ1: GASコードをコピー
            _buildStep(
              stepNumber: 1,
              title: 'GASコードをコピー',
              isCompleted: _isGasCodeCopied,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '以下のボタンをクリックして、GASコードをクリップボードにコピーしてください。',
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _copyGasCode,
                    icon: Icon(_isGasCodeCopied ? Icons.check : Icons.copy),
                    label:
                        Text(_isGasCodeCopied ? 'コピー済み' : 'GASコードをコピー'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isGasCodeCopied ? Colors.green : Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ステップ2: スプレッドシートを開いてGASを設定
            _buildStep(
              stepNumber: 2,
              title: 'スプレッドシートでGASを設定',
              isCompleted: _isSpreadsheetOpened,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '1. 以下のボタンで新年度のスプレッドシートを開いてください。',
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _openSpreadsheet,
                    icon: const Icon(Icons.open_in_new),
                    label: Text('${widget.nextYear}年度スプレッドシートを開く'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 詳細手順の表示/非表示
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _showInstructions = !_showInstructions;
                      });
                    },
                    icon: Icon(_showInstructions
                        ? Icons.expand_less
                        : Icons.expand_more),
                    label: Text(_showInstructions ? '手順を隠す' : '詳細手順を見る'),
                  ),

                  if (_showInstructions) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '【GAS設定手順】',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          _buildInstructionStep(
                              '2', 'スプレッドシートで「拡張機能」→「Apps Script」を選択'),
                          _buildInstructionStep(
                              '3', 'エディタが開いたら、既存のコードを全て削除'),
                          _buildInstructionStep(
                              '4', 'コピーしたGASコードを貼り付け（Ctrl+V または Cmd+V）'),
                          _buildInstructionStep('5', '保存（Ctrl+S または Cmd+S）'),
                          _buildInstructionStep(
                              '6', '「デプロイ」→「新しいデプロイ」をクリック'),
                          _buildInstructionStep(
                              '7', '「種類の選択」→「ウェブアプリ」を選択'),
                          _buildInstructionStep(
                              '8', '「次のユーザーとして実行」→「自分」を選択'),
                          _buildInstructionStep(
                              '9', '「アクセスできるユーザー」→「全員」を選択'),
                          _buildInstructionStep('10', '「デプロイ」をクリック'),
                          _buildInstructionStep(
                              '11', '表示される「ウェブアプリURL」をコピー'),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ステップ3: GAS URLを入力して登録
            _buildStep(
              stepNumber: 3,
              title: 'GAS URLを登録',
              isCompleted: _isUrlRegistered,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'デプロイで取得した「ウェブアプリURL」を以下に貼り付けて登録してください。',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _gasUrlController,
                    enabled: !_isUrlRegistered,
                    decoration: InputDecoration(
                      labelText: 'GAS URL',
                      hintText: 'https://script.google.com/macros/s/...',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.link),
                      suffixIcon: _isUrlRegistered
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                    ),
                    keyboardType: TextInputType.url,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _isUrlRegistered || _isRegistering
                        ? null
                        : _registerGasUrl,
                    icon: _isRegistering
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(_isUrlRegistered
                            ? Icons.check
                            : Icons.cloud_upload),
                    label: Text(_isRegistering
                        ? '登録中...'
                        : _isUrlRegistered
                            ? '登録済み'
                            : 'URLを登録'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _isUrlRegistered ? Colors.green : Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '登録後、新年度に切り替えるには「設定」画面から年度切替を行ってください。',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // 完了ボタン
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.done),
              label: const Text('閉じる'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'この画面は「設定」から再度確認できます',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep({
    required int stepNumber,
    required String title,
    required bool isCompleted,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isCompleted ? Colors.green : Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : Text(
                            stepNumber.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionStep(String number, String instruction) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number. ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(child: Text(instruction)),
        ],
      ),
    );
  }
}
