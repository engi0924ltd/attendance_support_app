import 'package:flutter/material.dart';
import '../../models/facility_admin.dart';
import '../common/menu_selection_screen.dart';
import '../../services/master_auth_service.dart';
import 'staff_list_screen.dart';
import 'user_list_screen.dart';
import 'daily_attendance_screen.dart';
import 'analytics_screen.dart';

/// 施設管理者ダッシュボード画面
class FacilityAdminDashboardScreen extends StatelessWidget {
  final FacilityAdmin admin;

  const FacilityAdminDashboardScreen({
    super.key,
    required this.admin,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(admin.facilityName),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: 'ログアウト',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // ヘッダー情報
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '施設管理者ダッシュボード',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('施設名: ${admin.facilityName}'),
                    Text('管理者: ${admin.adminName}'),
                    Text('年度: ${admin.fiscalYear ?? "未設定"}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 機能メニュー
            const Text(
              '管理機能',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // 本日の勤怠一覧
            _DashboardMenuItem(
              title: '本日の勤怠一覧',
              icon: Icons.today,
              color: Colors.green,
              onTap: () => _navigateToDailyAttendance(context),
            ),
            const SizedBox(height: 12),

            // 支援者アカウント管理
            _DashboardMenuItem(
              title: '支援者アカウント管理',
              icon: Icons.people,
              color: Colors.orange,
              onTap: () => _navigateToStaffManagement(context),
            ),
            const SizedBox(height: 12),

            // 利用者アカウント管理
            _DashboardMenuItem(
              title: '利用者アカウント管理',
              icon: Icons.person_add,
              color: Colors.purple,
              onTap: () => _navigateToUserManagement(context),
            ),
            const SizedBox(height: 12),

            // 統計・分析
            _DashboardMenuItem(
              title: '統計・分析',
              icon: Icons.analytics,
              color: Colors.indigo,
              onTap: () => _navigateToAnalytics(context),
            ),
            const SizedBox(height: 12),

            // 設定（準備中）
            _DashboardMenuItem(
              title: '設定',
              icon: Icons.settings,
              color: Colors.grey,
              onTap: () => _showComingSoonDialog(context, '設定'),
            ),
            const SizedBox(height: 24), // 下部に余白を追加
          ],
        ),
      ),
      ),
    );
  }

  void _navigateToDailyAttendance(BuildContext context) {
    if (admin.gasUrl == null || admin.gasUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GAS URLが設定されていません')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FacilityAdminDailyAttendanceScreen(
          gasUrl: admin.gasUrl!,
          facilityName: admin.facilityName,
          adminName: admin.adminName,
        ),
      ),
    );
  }

  void _navigateToStaffManagement(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StaffListScreen(gasUrl: admin.gasUrl),
      ),
    );
  }

  void _navigateToUserManagement(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserListScreen(gasUrl: admin.gasUrl),
      ),
    );
  }

  void _navigateToAnalytics(BuildContext context) {
    if (admin.gasUrl == null || admin.gasUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GAS URLが設定されていません')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FacilityAdminAnalyticsScreen(gasUrl: admin.gasUrl),
      ),
    );
  }

  void _showComingSoonDialog(BuildContext context, String featureName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('準備中'),
        content: Text('$featureName機能は現在準備中です。\n今後のアップデートをお待ちください。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ログアウト'),
        content: const Text('ログアウトしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final authService = MasterAuthService();
      // セッション情報のみクリア（保存した認証情報は維持）
      await authService.logoutSession();

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MenuSelectionScreen()),
        (route) => false,
      );
    }
  }
}

/// ダッシュボードメニュー項目
class _DashboardMenuItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DashboardMenuItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey.shade400,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
