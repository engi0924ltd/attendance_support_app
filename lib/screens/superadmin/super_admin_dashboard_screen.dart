import 'package:flutter/material.dart';
import '../../models/super_admin.dart';
import '../../models/facility.dart';
import '../../services/facility_service.dart';
import '../../services/master_auth_service.dart';
import '../common/menu_selection_screen.dart';
import '../facility_admin/facility_admin_dashboard_screen.dart';
import '../facility_admin/chatwork_settings_screen.dart';
import '../../models/facility_admin.dart';
import 'facility_registration_screen.dart';
import 'facility_setup_wizard_screen.dart';
import 'facility_edit_screen.dart';

/// 全権管理者ダッシュボード画面
class SuperAdminDashboardScreen extends StatefulWidget {
  final SuperAdmin admin;

  const SuperAdminDashboardScreen({
    super.key,
    required this.admin,
  });

  @override
  State<SuperAdminDashboardScreen> createState() =>
      _SuperAdminDashboardScreenState();
}

class _SuperAdminDashboardScreenState extends State<SuperAdminDashboardScreen> {
  final FacilityService _facilityService = FacilityService();
  List<Facility> _facilities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFacilities();
  }

  /// 施設一覧を読み込む
  Future<void> _loadFacilities() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final facilities = await _facilityService.getAllFacilities();
      setState(() {
        _facilities = facilities;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorDialog('施設一覧の取得に失敗しました\n$e');
      }
    }
  }

  /// 施設管理者としてログイン
  Future<void> _loginAsFacility(Facility facility) async {
    // 施設管理者オブジェクトを作成
    final facilityAdmin = FacilityAdmin(
      facilityId: facility.facilityId,
      facilityName: facility.facilityName,
      adminName: facility.adminName,
      email: facility.adminEmail,
      permissionLevel: 1,
      spreadsheetId: facility.spreadsheetId,
      fiscalYear: facility.fiscalYear,
      gasUrl: facility.gasUrl,
      timeRounding: facility.timeRounding,
    );

    // 施設のGAS URLと時間設定を保存
    final authService = MasterAuthService();
    if (facilityAdmin.gasUrl != null && facilityAdmin.gasUrl!.isNotEmpty) {
      await authService.saveFacilityGasUrl(facilityAdmin.gasUrl!);
    }
    if (facilityAdmin.timeRounding != null && facilityAdmin.timeRounding!.isNotEmpty) {
      await authService.saveFacilityTimeRounding(facilityAdmin.timeRounding!);
    }

    // 施設管理者ダッシュボードへ遷移
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FacilityAdminDashboardScreen(
          admin: facilityAdmin,
        ),
      ),
    );
  }

  /// 新規施設登録画面へ遷移
  void _navigateToAddFacility() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FacilityRegistrationScreen(),
      ),
    );

    // 登録成功した場合は施設一覧を再読み込み
    if (result == true) {
      _loadFacilities();
    }
  }

  /// 施設セットアップウィザードへ遷移
  void _setupFacility(Facility facility) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => FacilitySetupWizardScreen(
          facility: facility,
        ),
      ),
    );

    // セットアップ完了した場合は施設一覧を再読み込み
    if (result == true) {
      _loadFacilities();
    }
  }

  /// 施設編集画面へ遷移
  void _editFacility(Facility facility) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => FacilityEditScreen(
          facility: facility,
        ),
      ),
    );

    // 更新成功した場合は施設一覧を再読み込み
    if (result == true) {
      _loadFacilities();
    }
  }

  /// Chatwork設定画面へ遷移
  void _openChatworkSettings(Facility facility) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => ChatworkSettingsScreen(
          facility: facility,
        ),
      ),
    );

    // 保存成功した場合は施設一覧を再読み込み
    if (result == true) {
      _loadFacilities();
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

  Future<void> _logout() async {
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

    if (confirm == true && mounted) {
      final authService = MasterAuthService();
      await authService.clearLoginCredentials();
      await authService.logout();

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MenuSelectionScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('全権管理者'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'ログアウト',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadFacilities,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ヘッダー情報
                      Card(
                        color: Colors.purple.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '全権管理者ダッシュボード',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple.shade900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text('管理者: ${widget.admin.adminName}'),
                              Text('メール: ${widget.admin.email}'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 施設一覧ヘッダー
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '登録施設一覧 (${_facilities.length}件)',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _loadFacilities,
                            tooltip: '更新',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 施設一覧
                      if (_facilities.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Text(
                              '登録されている施設がありません',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        )
                      else
                        ..._facilities.map((facility) =>
                            _FacilityCard(
                              facility: facility,
                              onLogin: () => _loginAsFacility(facility),
                              onSetup: () => _setupFacility(facility),
                              onEdit: () => _editFacility(facility),
                              onChatwork: () => _openChatworkSettings(facility),
                            )),

                      const SizedBox(height: 24),

                      // 新規施設登録ボタン
                      ElevatedButton.icon(
                        onPressed: _navigateToAddFacility,
                        icon: const Icon(Icons.add),
                        label: const Text('新規施設登録'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

/// 施設カード
class _FacilityCard extends StatelessWidget {
  final Facility facility;
  final VoidCallback onLogin;
  final VoidCallback onSetup;
  final VoidCallback onEdit;
  final VoidCallback onChatwork;

  const _FacilityCard({
    required this.facility,
    required this.onLogin,
    required this.onSetup,
    required this.onEdit,
    required this.onChatwork,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.business,
                    color: Colors.blue,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        facility.facilityName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '管理者: ${facility.adminName}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _InfoChip(
                  icon: Icons.calendar_today,
                  label: '年度: ${facility.fiscalYear ?? "未設定"}',
                ),
                const SizedBox(width: 8),
                _InfoChip(
                  icon: Icons.badge,
                  label: 'ID: ${facility.facilityId}',
                ),
              ],
            ),
            const SizedBox(height: 8),
            // セットアップ状態バッジ
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: facility.isSetupComplete
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
                border: Border.all(
                  color: facility.isSetupComplete
                      ? Colors.green.shade300
                      : Colors.orange.shade300,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    facility.isSetupComplete
                        ? Icons.check_circle
                        : Icons.warning,
                    size: 14,
                    color: facility.isSetupComplete
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    facility.isSetupComplete
                        ? 'セットアップ完了'
                        : 'セットアップが必要です',
                    style: TextStyle(
                      fontSize: 12,
                      color: facility.isSetupComplete
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // ボタン（1行目：編集・Chatwork）
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('編集'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onChatwork,
                    icon: const Icon(Icons.chat, size: 18),
                    label: const Text('Chatwork'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // ボタン（2行目：GAS更新/セットアップ）
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onSetup,
                icon: const Icon(Icons.settings, size: 18),
                label: Text(
                  facility.isSetupComplete ? 'GAS更新' : 'セットアップ',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: facility.isSetupComplete
                      ? Colors.deepPurple
                      : Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // ボタン（3行目：施設としてログイン）
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onLogin,
                icon: const Icon(Icons.login, size: 18),
                label: const Text('施設としてログイン'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 情報チップ
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
