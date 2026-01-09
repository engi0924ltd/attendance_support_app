import 'package:flutter/material.dart';
import '../../services/master_auth_service.dart';
import '../facility_admin/facility_admin_dashboard_screen_v2.dart';
import 'super_admin_dashboard_screen.dart';

/// 統合管理者ログイン画面（全権管理者 or 施設管理者）
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final MasterAuthService _authService = MasterAuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// 保存された認証情報を読み込む
  Future<void> _loadSavedCredentials() async {
    final credentials = await _authService.getSavedCredentials();
    if (credentials != null) {
      setState(() {
        _emailController.text = credentials['email']!;
        _passwordController.text = credentials['password']!;
        _rememberMe = true;
      });
    }
  }

  /// ログイン処理
  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      _showErrorDialog('メールアドレスを入力してください');
      return;
    }

    // 簡易的なメールアドレスチェック
    if (!email.contains('@')) {
      _showErrorDialog('正しいメールアドレスを入力してください');
      return;
    }

    if (password.isEmpty) {
      _showErrorDialog('パスワードを入力してください');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _authService.unifiedAdminLogin(email, password);

      // ログイン状態を保持する場合
      if (_rememberMe) {
        await _authService.saveLoginCredentials(email, password);
      } else {
        await _authService.clearLoginCredentials();
      }

      if (mounted) {
        // アカウントタイプによって遷移先を変更
        if (result.isSuperAdmin()) {
          // 全権管理者の場合
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => SuperAdminDashboardScreen(
                admin: result.superAdmin!,
              ),
            ),
          );
        } else if (result.isFacilityAdmin()) {
          // 施設管理者の場合：施設のGAS URLと時間設定を保存
          final facilityAdmin = result.facilityAdmin!;
          if (facilityAdmin.gasUrl != null && facilityAdmin.gasUrl!.isNotEmpty) {
            await _authService.saveFacilityGasUrl(facilityAdmin.gasUrl!);
          }
          if (facilityAdmin.timeRounding != null && facilityAdmin.timeRounding!.isNotEmpty) {
            await _authService.saveFacilityTimeRounding(facilityAdmin.timeRounding!);
          }

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => FacilityAdminDashboardScreenV2(
                admin: facilityAdmin,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('ログインに失敗しました\n$e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('エラー'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('管理者ログイン'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.admin_panel_settings,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 32),
            const Text(
              '管理者ログイン',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 48),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'メールアドレス',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
                hintText: 'admin@example.com',
              ),
              keyboardType: TextInputType.emailAddress,
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'パスワード',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              obscureText: _obscurePassword,
              enabled: !_isLoading,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Checkbox(
                  value: _rememberMe,
                  onChanged: _isLoading
                      ? null
                      : (value) {
                          setState(() {
                            _rememberMe = value ?? false;
                          });
                        },
                ),
                const Text('ログイン状態を保持する'),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('ログイン'),
            ),
          ],
        ),
      ),
    );
  }
}
