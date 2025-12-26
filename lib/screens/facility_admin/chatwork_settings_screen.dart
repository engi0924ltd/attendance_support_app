import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../models/facility.dart';
import '../../services/facility_service.dart';

/// Chatwork設定画面
class ChatworkSettingsScreen extends StatefulWidget {
  final Facility facility;

  const ChatworkSettingsScreen({
    super.key,
    required this.facility,
  });

  @override
  State<ChatworkSettingsScreen> createState() => _ChatworkSettingsScreenState();
}

class _ChatworkSettingsScreenState extends State<ChatworkSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiTokenController = TextEditingController();
  final FacilityService _facilityService = FacilityService();

  bool _isSaving = false;
  bool _obscureApiToken = true;

  @override
  void initState() {
    super.initState();
    // 施設の既存APIキーを設定
    _apiTokenController.text = widget.facility.chatworkApiKey ?? '';
  }

  @override
  void dispose() {
    _apiTokenController.dispose();
    super.dispose();
  }

  /// 設定を保存する
  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final apiKey = _apiTokenController.text.trim();

      // 1. マスターシートに保存
      await _facilityService.updateChatworkApiKey(
        widget.facility.facilityId,
        apiKey,
      );

      // 2. 施設のGASにもAPIキーを設定（施設GAS URLが設定されている場合）
      if (widget.facility.gasUrl != null && widget.facility.gasUrl!.isNotEmpty) {
        await _setApiKeyToFacilityGas(widget.facility.gasUrl!, apiKey);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('APIキーを保存しました'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // 保存成功を返す
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存に失敗しました: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  /// 施設のGASにAPIキーを設定
  Future<void> _setApiKeyToFacilityGas(String gasUrl, String apiKey) async {
    try {
      final response = await http.post(
        Uri.parse(gasUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'chatwork/set-api-key',
          'apiKey': apiKey,
        }),
      );

      if (response.statusCode != 200) {
        // GASへの設定失敗は警告のみ（マスター保存は成功しているため）
        debugPrint('施設GASへのAPIキー設定失敗: ${response.statusCode}');
      }
    } catch (e) {
      // GASへの設定失敗は警告のみ
      debugPrint('施設GASへのAPIキー設定エラー: $e');
    }
  }

  /// ChatworkのAPI設定ページを開く
  Future<void> _openChatworkApiPage() async {
    final uri = Uri.parse('https://www.chatwork.com/service/packages/chatwork/subpackages/api/token.php');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chatwork設定'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 施設名表示
              Card(
                color: Colors.grey.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.business, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '施設: ${widget.facility.facilityName}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // APIトークン取得方法の説明
              _buildApiTokenGuide(),
              const SizedBox(height: 24),

              // 設定入力フォーム
              _buildSettingsForm(),
              const SizedBox(height: 32),

              // 保存ボタン
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          '設定を保存',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// APIトークン取得方法のガイド
  Widget _buildApiTokenGuide() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'APIトークンの取得方法',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Chatwork APIを使用するには、APIトークンが必要です。\n以下の手順で取得してください：',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            _buildStep('1', 'Chatworkにログインします'),
            _buildStep('2', '右上のアカウント名をクリック'),
            _buildStep('3', '「サービス連携」を選択'),
            _buildStep('4', '「APIトークン」をクリック'),
            _buildStep('5', 'パスワードを入力してトークンを表示'),
            _buildStep('6', '表示されたトークンをコピー'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _openChatworkApiPage,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Chatwork API設定ページを開く'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ステップ表示
  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue.shade700,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// 設定入力フォーム
  Widget _buildSettingsForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'APIキー設定',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // APIトークン入力
            TextFormField(
              controller: _apiTokenController,
              obscureText: _obscureApiToken,
              decoration: InputDecoration(
                labelText: 'APIトークン',
                hintText: 'Chatworkで取得したAPIトークンを入力',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.key),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _obscureApiToken ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() => _obscureApiToken = !_obscureApiToken);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () {
                        if (_apiTokenController.text.isNotEmpty) {
                          Clipboard.setData(ClipboardData(text: _apiTokenController.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('コピーしました')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'APIトークンを入力してください';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 注意事項
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'APIトークンは機密情報です。第三者に公開しないでください。',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
