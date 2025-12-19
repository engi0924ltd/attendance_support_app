import 'package:flutter/material.dart';
import '../../services/master_auth_service.dart';
import '../../models/facility.dart';
import '../common/menu_selection_screen.dart';
import 'facility_setup_wizard_screen.dart';

/// 施設コードによるセットアップ画面（複数PC設定用）
class FacilityCodeSetupScreen extends StatefulWidget {
  const FacilityCodeSetupScreen({super.key});

  @override
  State<FacilityCodeSetupScreen> createState() =>
      _FacilityCodeSetupScreenState();
}

class _FacilityCodeSetupScreenState extends State<FacilityCodeSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _facilityCodeController = TextEditingController();
  final _facilityPasswordController = TextEditingController();
  final _authService = MasterAuthService();
  bool _isLoading = false;
  bool _passwordVisible = false;

  @override
  void dispose() {
    _facilityCodeController.dispose();
    _facilityPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSetup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final facilityData = await _authService.getFacilityByCode(
        _facilityCodeController.text.trim(),
        _facilityPasswordController.text.trim(),
      );

      if (!mounted) return;

      // デバッグ：保存されたGAS URLを確認
      final savedUrl = await _authService.getFacilityGasUrl();
      final gasUrl = facilityData['gasUrl']?.toString() ?? '';
      print('🔍 DEBUG: facilityData gasUrl = $gasUrl');
      print('🔍 DEBUG: saved gasUrl = $savedUrl');

      if (gasUrl.isEmpty) {
        // GAS URLが未設定の場合はセットアップウィザードへ遷移
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('施設「${facilityData['facilityName']}」を認証しました。\nGASのセットアップが必要です。'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );

        // Facilityオブジェクトを作成
        final facility = Facility(
          facilityId: facilityData['facilityId']?.toString() ?? '',
          facilityName: facilityData['facilityName']?.toString() ?? '',
          adminName: '',
          adminEmail: '',
          spreadsheetId: facilityData['spreadsheetId']?.toString(),
          fiscalYear: facilityData['fiscalYear']?.toString(),
          gasUrl: gasUrl,
          status: '有効',
          timeRounding: facilityData['timeRounding']?.toString(),
          facilityCode: _facilityCodeController.text.trim(),
          facilityPassword: _facilityPasswordController.text.trim(),
        );

        // セットアップウィザードへ遷移
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => FacilitySetupWizardScreen(facility: facility),
          ),
        );
      } else {
        // GAS URLが設定済みの場合はメニュー選択画面へ
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('施設情報を設定しました: ${facilityData['facilityName']}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // メニュー選択画面に遷移
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const MenuSelectionScreen(),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('エラー: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
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
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // アイコン
                const Icon(
                  Icons.settings_applications,
                  size: 80,
                  color: Colors.blue,
                ),
                const SizedBox(height: 24),

                // タイトル
                const Text(
                  '施設コードでセットアップ',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // 説明文
                const Text(
                  '施設管理者から受け取った施設コードと施設パスワードを入力してください',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // 施設コード入力欄
                TextFormField(
                  controller: _facilityCodeController,
                  decoration: const InputDecoration(
                    labelText: '施設コード',
                    hintText: '6桁の数字',
                    prefixIcon: Icon(Icons.pin),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '施設コードを入力してください';
                    }
                    if (value.trim().length != 6) {
                      return '施設コードは6桁です';
                    }
                    if (!RegExp(r'^\d+$').hasMatch(value.trim())) {
                      return '施設コードは数字のみです';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 施設パスワード入力欄
                TextFormField(
                  controller: _facilityPasswordController,
                  decoration: InputDecoration(
                    labelText: '施設パスワード',
                    hintText: '8桁の英数字',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _passwordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _passwordVisible = !_passwordVisible;
                        });
                      },
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  obscureText: !_passwordVisible,
                  maxLength: 8,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '施設パスワードを入力してください';
                    }
                    if (value.trim().length != 8) {
                      return '施設パスワードは8桁です';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // セットアップボタン
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSetup,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          '施設情報を取得',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
                const SizedBox(height: 16),

                // キャンセルボタン
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          Navigator.of(context).pop();
                        },
                  child: const Text('戻る'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
