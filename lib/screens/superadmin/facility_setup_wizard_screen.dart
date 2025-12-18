import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/facility.dart';
import '../../services/facility_service.dart';

/// 施設セットアップウィザード画面
class FacilitySetupWizardScreen extends StatefulWidget {
  final Facility facility;

  const FacilitySetupWizardScreen({
    super.key,
    required this.facility,
  });

  @override
  State<FacilitySetupWizardScreen> createState() =>
      _FacilitySetupWizardScreenState();
}

class _FacilitySetupWizardScreenState
    extends State<FacilitySetupWizardScreen> {
  final FacilityService _facilityService = FacilityService();
  final TextEditingController _gasUrlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isGasCodeCopied = false;
  bool _isSpreadsheetOpened = false;
  bool _isLoading = false;
  bool _showInstructions = false;

  @override
  void dispose() {
    _gasUrlController.dispose();
    super.dispose();
  }

  /// GASコードをクリップボードにコピー
  Future<void> _copyGasCode() async {
    try {
      // アセットから実際のGASコードを読み込む
      final gasCode = await rootBundle.loadString('assets/gas/gas_code_v2.js');

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
    if (widget.facility.spreadsheetId == null ||
        widget.facility.spreadsheetId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('スプレッドシートIDが見つかりません')),
      );
      return;
    }

    final url = Uri.parse(
        'https://docs.google.com/spreadsheets/d/${widget.facility.spreadsheetId}/edit');

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

  /// セットアップを完了
  Future<void> _completeSetup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _facilityService.updateFacilityGasUrl(
        widget.facility.facilityId,
        _gasUrlController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('セットアップが完了しました！'),
            backgroundColor: Colors.green,
          ),
        );

        // 前の画面に戻る（施設一覧を更新）
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('施設セットアップ'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ヘッダー
              Card(
                color: Colors.purple.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '施設「${widget.facility.facilityName}」のセットアップ',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '以下の手順に従って、施設専用のGASをセットアップしてください。',
                        style: TextStyle(fontSize: 14),
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
                      label: Text(
                          _isGasCodeCopied ? 'コピー済み' : 'GASコードをコピー'),
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

              // ステップ2: スプレッドシートを開いてGASを貼り付け
              _buildStep(
                stepNumber: 2,
                title: 'スプレッドシートでGASを設定',
                isCompleted: _isSpreadsheetOpened,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '1. 以下のボタンでスプレッドシートを開いてください。',
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _openSpreadsheet,
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('スプレッドシートを開く'),
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
                            _buildInstructionStep('7', '「種類の選択」→「ウェブアプリ」を選択'),
                            _buildInstructionStep('8', '「次のユーザーとして実行」→「自分」を選択'),
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

              // ステップ3: GAS URLを入力
              _buildStep(
                stepNumber: 3,
                title: 'GAS URLを入力',
                isCompleted: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'デプロイ後に表示された「ウェブアプリURL」を以下に貼り付けてください。',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _gasUrlController,
                      decoration: const InputDecoration(
                        labelText: 'GAS URL *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.link),
                        hintText:
                            'https://script.google.com/macros/s/.../exec',
                      ),
                      enabled: !_isLoading,
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'GAS URLを入力してください';
                        }
                        if (!value
                            .startsWith('https://script.google.com/macros/')) {
                          return '正しいGAS URLを入力してください';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // 完了ボタン
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _completeSetup,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle),
                label: Text(_isLoading ? '保存中...' : 'セットアップを完了'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // スキップボタン
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('後でセットアップする'),
              ),
            ],
          ),
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
                    color: isCompleted ? Colors.green : Colors.purple,
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
