import 'package:flutter/material.dart';
import '../user/user_select_screen.dart';
import '../staff/login_screen.dart';
import '../staff/daily_attendance_list_screen.dart';
import '../superadmin/admin_login_screen.dart';
import '../../services/auth_service.dart';

/// 最初の画面：利用者メニューか支援者メニューを選ぶ
class MenuSelectionScreen extends StatefulWidget {
  const MenuSelectionScreen({super.key});

  @override
  State<MenuSelectionScreen> createState() => _MenuSelectionScreenState();
}

class _MenuSelectionScreenState extends State<MenuSelectionScreen> {
  final AuthService _authService = AuthService();
  bool _isCheckingLogin = true;

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
  }

  /// 自動ログインをチェック
  Future<void> _checkAutoLogin() async {
    try {
      final credentials = await _authService.getSavedCredentials();

      if (credentials != null && mounted) {
        // 保存された認証情報で自動ログイン（タイムアウト付き）
        final staff = await _authService
            .staffLogin(
              credentials['email']!,
              credentials['password']!,
            )
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                throw Exception('ログインタイムアウト');
              },
            );

        if (mounted) {
          // 自動ログイン成功：支援者メニューへ
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => DailyAttendanceListScreen(
                staffName: staff.name,
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _isCheckingLogin = false;
          });
        }
      }
    } catch (e) {
      // 自動ログイン失敗：保存された認証情報をクリア
      await _authService.clearLoginCredentials();
      if (mounted) {
        setState(() {
          _isCheckingLogin = false;
        });
      }
    }
  }

  /// 支援者メニューへ遷移（ログイン状態をチェック）
  Future<void> _navigateToStaffMenu() async {
    // 保存された認証情報をチェック
    final credentials = await _authService.getSavedCredentials();

    if (credentials != null) {
      // ローディングダイアログを表示
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      // 自動ログインを試みる
      try {
        final staff = await _authService.staffLogin(
          credentials['email']!,
          credentials['password']!,
        );

        if (mounted) {
          // ローディングダイアログを閉じる
          Navigator.pop(context);

          // ログイン成功：出勤一覧画面へ直接遷移
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DailyAttendanceListScreen(
                staffName: staff.name,
              ),
            ),
          );
        }
      } catch (e) {
        // ログイン失敗：認証情報をクリアしてログイン画面へ
        await _authService.clearLoginCredentials();
        if (mounted) {
          // ローディングダイアログを閉じる
          Navigator.pop(context);

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const StaffLoginScreen(),
            ),
          );
        }
      }
    } else {
      // 認証情報がない：ログイン画面へ
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const StaffLoginScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingLogin) {
      // 自動ログインチェック中
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade400,
              Colors.blue.shade700,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // アプリのタイトル
                const Text(
                  'B型施設',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '支援者サポートアプリ',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 80),

                // 利用者メニューボタン
                _MenuButton(
                  label: '利用者メニュー',
                  icon: Icons.person,
                  color: Colors.green,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UserSelectScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // 支援者メニューボタン
                _MenuButton(
                  label: '支援者メニュー',
                  icon: Icons.business_center,
                  color: Colors.orange,
                  onTap: _navigateToStaffMenu,
                ),
                const SizedBox(height: 24),

                // 管理者メニューボタン
                _MenuButton(
                  label: '管理者メニュー',
                  icon: Icons.admin_panel_settings,
                  color: Colors.blue,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminLoginScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// メニューボタンの部品
class _MenuButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MenuButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 280,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 48,
              color: color,
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
