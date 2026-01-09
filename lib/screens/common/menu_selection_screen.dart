import 'package:flutter/material.dart';
import '../user/user_select_screen.dart';
import '../staff/login_screen.dart';
import '../superadmin/admin_login_screen.dart';
import '../superadmin/facility_code_setup_screen.dart';
import '../../services/master_auth_service.dart';

/// 最初の画面：利用者メニューか支援者メニューを選ぶ
class MenuSelectionScreen extends StatefulWidget {
  const MenuSelectionScreen({super.key});

  @override
  State<MenuSelectionScreen> createState() => _MenuSelectionScreenState();
}

class _MenuSelectionScreenState extends State<MenuSelectionScreen> {
  final MasterAuthService _masterAuthService = MasterAuthService();

  /// 利用者メニューへ遷移（施設設定をチェック）
  Future<void> _navigateToUserMenu() async {
    // 施設のGAS URLがあるかチェック
    final gasUrl = await _masterAuthService.getFacilityGasUrl();

    // デバッグ：保存されているGAS URLを確認
    print('🔍 DEBUG _navigateToUserMenu: gasUrl = $gasUrl');
    print('🔍 DEBUG _navigateToUserMenu: isEmpty = ${gasUrl?.isEmpty ?? true}');

    if (mounted) {
      if (gasUrl == null || gasUrl.isEmpty) {
        // 施設が設定されていない場合は施設コード入力画面へ
        print('🔍 DEBUG: 施設コード入力画面に遷移');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const FacilityCodeSetupScreen(),
          ),
        );
      } else {
        // 施設が設定されている場合は利用者選択画面へ
        print('🔍 DEBUG: 利用者選択画面に遷移');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const UserSelectScreen(),
          ),
        );
      }
    }
  }

  /// 支援者メニューへ遷移（施設設定をチェック）
  Future<void> _navigateToStaffMenu() async {
    // 施設のGAS URLがあるかチェック
    final gasUrl = await _masterAuthService.getFacilityGasUrl();

    if (mounted) {
      if (gasUrl == null || gasUrl.isEmpty) {
        // 施設が設定されていない場合は施設コード入力画面へ
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const FacilityCodeSetupScreen(),
          ),
        );
      } else {
        // 施設が設定されている場合は支援者ログイン画面へ
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const StaffLoginScreen(),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  onTap: _navigateToUserMenu,
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
