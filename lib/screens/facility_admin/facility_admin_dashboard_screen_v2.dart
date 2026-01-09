import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/facility_admin.dart';
import '../../models/attendance.dart';
import '../../theme/app_theme_v2.dart';
import '../../services/master_auth_service.dart';
import '../../services/attendance_service.dart';
import '../../config/constants.dart';
import '../common/menu_selection_screen.dart';
import '../staff/user_detail_screen.dart';
import 'staff_list_screen.dart';
import 'user_list_screen.dart';
import 'daily_attendance_screen.dart';
import 'analytics_screen.dart';
import 'settings_screen.dart';
import 'billing_settings_screen.dart';

/// 施設管理者ダッシュボード画面（V2: プロフェッショナルデザイン）
///
/// デザインコンセプト：「信頼感 × 温かみ × 効率性」
/// - 白ベースの清潔感
/// - 落ち着いた緑のプライマリカラー
/// - クリーンな影とボーダー
class FacilityAdminDashboardScreenV2 extends StatefulWidget {
  final FacilityAdmin admin;

  const FacilityAdminDashboardScreenV2({
    super.key,
    required this.admin,
  });

  @override
  State<FacilityAdminDashboardScreenV2> createState() =>
      _FacilityAdminDashboardScreenV2State();
}

class _FacilityAdminDashboardScreenV2State
    extends State<FacilityAdminDashboardScreenV2> {
  final AttendanceService _attendanceService = AttendanceService();

  // ステータスカウント
  int _scheduledCount = 0; // 出勤予定
  int _checkedInCount = 0; // 出勤者数
  int _notCheckedInCount = 0; // 未出勤
  int _notRegisteredCount = 0; // 記録未登録
  bool _isLoadingStats = true;

  // 記録未登録の利用者リスト
  List<Map<String, dynamic>> _notRegisteredUsers = [];

  // 受給者証期限切れアラート
  List<Map<String, dynamic>> _certificateAlerts = [];
  bool _isLoadingAlerts = true;

  @override
  void initState() {
    super.initState();
    _loadTodayStats();
    _loadCertificateAlerts();
  }

  /// 本日のステータスを読み込む
  Future<void> _loadTodayStats() async {
    if (widget.admin.gasUrl == null || widget.admin.gasUrl!.isEmpty) {
      setState(() {
        _isLoadingStats = false;
      });
      return;
    }

    // ローディング状態を開始
    setState(() {
      _isLoadingStats = true;
    });

    try {
      final dateStr = DateFormat(AppConstants.dateFormat).format(DateTime.now());

      // 予定者リストと実際の出勤記録を並行取得
      final results = await Future.wait([
        _attendanceService.getScheduledUsers(dateStr),
        _attendanceService.getDailyAttendance(dateStr),
      ]);

      final scheduledUsers = results[0] as List<Map<String, dynamic>>;
      final attendances = results[1] as List<Attendance>;

      int scheduled = 0;
      int notCheckedIn = 0;
      int notRegistered = 0;
      final notRegisteredUsers = <Map<String, dynamic>>[];

      for (final user in scheduledUsers) {
        final hasCheckedIn = user['hasCheckedIn'] as bool? ?? false;
        final attendance = user['attendance'] as Attendance?;
        final userName = user['userName'] as String? ?? '';

        scheduled++;

        if (hasCheckedIn) {
          // 出勤済みで支援記録未入力
          if (attendance != null && !attendance.hasSupportRecord) {
            notRegistered++;
            notRegisteredUsers.add({
              'userName': userName,
              'status': attendance.attendanceStatus ?? '出勤',
              'attendance': attendance,
            });
          }
        } else {
          notCheckedIn++;
          // 欠勤・事前連絡あり欠勤で支援記録未入力もカウント
          if (attendance != null) {
            final status = attendance.attendanceStatus;
            final isAbsent = status == '欠勤' || status == '事前連絡あり欠勤';
            if (isAbsent && !attendance.hasSupportRecord) {
              notRegistered++;
              notRegisteredUsers.add({
                'userName': userName,
                'status': status,
                'attendance': attendance,
              });
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _scheduledCount = scheduled;
          // 出勤済み = 実際の出勤記録数（予定外出勤も含む）
          _checkedInCount = attendances.length;
          // 未出勤 = 予定者のうちまだ出勤していない人
          _notCheckedInCount = notCheckedIn;
          _notRegisteredCount = notRegistered;
          _notRegisteredUsers = notRegisteredUsers;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    }
  }

  /// 受給者証期限切れアラートを読み込む
  Future<void> _loadCertificateAlerts() async {
    if (widget.admin.gasUrl == null || widget.admin.gasUrl!.isEmpty) {
      print('🔍 [CertificateAlerts] GAS URLが空です');
      setState(() {
        _isLoadingAlerts = false;
      });
      return;
    }

    setState(() {
      _isLoadingAlerts = true;
    });

    try {
      print('🔍 [CertificateAlerts] API呼び出し開始');
      final alerts = await _attendanceService.getCertificateAlerts();
      print('🔍 [CertificateAlerts] 取得結果: ${alerts.length}件');
      if (mounted) {
        setState(() {
          _certificateAlerts = alerts;
          _isLoadingAlerts = false;
        });
      }
    } catch (e) {
      print('❌ [CertificateAlerts] エラー: $e');
      if (mounted) {
        setState(() {
          _isLoadingAlerts = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CleanScaffold(
      appBar: CleanAppBar(
        title: widget.admin.facilityName,
        showBackButton: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => _logout(context),
            tooltip: 'ログアウト',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTodayStats,
        color: AppThemeV2.primaryGreen,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 受給者証期限切れアラート
                if (!_isLoadingAlerts && _certificateAlerts.isNotEmpty)
                  _buildCertificateAlert(),

                // ウェルカムヘッダー
                _buildWelcomeHeader(),
                const SizedBox(height: 24),

                // 本日のステータス
                SectionHeader(
                  title: '本日のステータス',
                  icon: Icons.schedule,
                  trailing: _isLoadingStats
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppThemeV2.primaryGreen,
                          ),
                        )
                      : GestureDetector(
                          onTap: _loadTodayStats,
                          child: Icon(
                            Icons.refresh,
                            size: 20,
                            color: AppThemeV2.primaryGreen,
                          ),
                        ),
                ),
                _buildQuickStats(),
                const SizedBox(height: 28),

                // メインメニュー
                const SectionHeader(
                  title: '管理機能',
                  icon: Icons.apps,
                ),
                _buildMainMenu(context),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 受給者証期限切れアラートカード
  Widget _buildCertificateAlert() {
    return GestureDetector(
      onTap: _showCertificateAlerts,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppThemeV2.errorColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppThemeV2.errorColor.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppThemeV2.errorColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppThemeV2.errorColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '受給者証の期限切れ（${_certificateAlerts.length}名）',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppThemeV2.errorColor,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppThemeV2.errorColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// 受給者証期限切れの詳細を表示
  void _showCertificateAlerts() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ハンドル
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // ヘッダー
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppThemeV2.errorColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: AppThemeV2.errorColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '受給者証の期限切れ（${_certificateAlerts.length}名）',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppThemeV2.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // リスト
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _certificateAlerts.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final alert = _certificateAlerts[index];
                  final userName = alert['userName'] as String? ?? '';
                  final expiredItems = alert['expiredItems'] as List<dynamic>? ?? [];

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppThemeV2.errorColor.withOpacity(0.1),
                      child: Text(
                        userName.isNotEmpty ? userName[0] : '?',
                        style: const TextStyle(
                          color: AppThemeV2.errorColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppThemeV2.textPrimary,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: expiredItems.map((item) {
                        final label = item['label'] as String? ?? '';
                        final expiredDate = item['expiredDate'] as String? ?? '';
                        final formattedDate = _formatDateToJapanese(expiredDate);
                        return Text(
                          '$label: $formattedDate',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppThemeV2.errorColor,
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 日付を「年月日」形式にフォーマット
  String _formatDateToJapanese(String dateStr) {
    if (dateStr.isEmpty) return '';

    // yyyy/mm/dd または yyyymmdd 形式に対応
    try {
      final cleaned = dateStr.replaceAll('/', '');
      if (cleaned.length >= 8) {
        final year = cleaned.substring(0, 4);
        final month = int.parse(cleaned.substring(4, 6)).toString();
        final day = int.parse(cleaned.substring(6, 8)).toString();
        return '$year年$month月$day日';
      }
    } catch (e) {
      // パース失敗時は元の文字列を返す
    }
    return dateStr;
  }

  /// ウェルカムヘッダー
  Widget _buildWelcomeHeader() {
    return CleanCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // アイコン
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppThemeV2.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.business,
              color: AppThemeV2.primaryGreen,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          // テキスト
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '管理者ダッシュボード',
                  style: AppThemeV2.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.admin.adminName} さん',
                  style: AppThemeV2.bodyMedium,
                ),
              ],
            ),
          ),
          // 年度バッジ
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppThemeV2.primaryGreen,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${widget.admin.fiscalYear ?? "未設定"}年度',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// クイックステータス（4項目：1行×4列）
  Widget _buildQuickStats() {
    if (_isLoadingStats) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(color: AppThemeV2.primaryGreen),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: _QuickStatCard(
            label: '出勤予定',
            value: '$_scheduledCount',
            unit: '名',
            description: '本日の予定者',
            color: AppThemeV2.infoColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickStatCard(
            label: '出勤済',
            value: '$_checkedInCount',
            unit: '名',
            description: '出勤した人',
            color: AppThemeV2.primaryGreen,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _QuickStatCard(
            label: '未出勤',
            value: '$_notCheckedInCount',
            unit: '名',
            description: '予定あり未着',
            color: _notCheckedInCount > 0
                ? AppThemeV2.errorColor
                : AppThemeV2.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: _showNotRegisteredUsers,
            behavior: HitTestBehavior.opaque,
            child: _QuickStatCard(
              label: '記録未',
              value: '$_notRegisteredCount',
              unit: '名',
              description: '支援記録未入力',
              color: _notRegisteredCount > 0
                  ? AppThemeV2.accentOrange
                  : AppThemeV2.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  /// 記録未登録の利用者一覧を表示
  void _showNotRegisteredUsers() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ハンドル
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // ヘッダー
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppThemeV2.accentOrange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.edit_note,
                      color: AppThemeV2.accentOrange,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '支援記録未入力（${_notRegisteredUsers.length}名）',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppThemeV2.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // リスト
            Flexible(
              child: _notRegisteredUsers.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 48,
                              color: AppThemeV2.primaryGreen,
                            ),
                            SizedBox(height: 12),
                            Text(
                              '全員の支援記録が入力済みです',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppThemeV2.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _notRegisteredUsers.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final user = _notRegisteredUsers[index];
                        final userName = user['userName'] as String;
                        final status = user['status'] as String? ?? '';

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppThemeV2.accentOrange.withValues(alpha: 0.1),
                            child: Text(
                              userName.isNotEmpty ? userName[0] : '?',
                              style: const TextStyle(
                                color: AppThemeV2.accentOrange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            userName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppThemeV2.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            status,
                            style: TextStyle(
                              fontSize: 12,
                              color: status.contains('欠')
                                  ? AppThemeV2.errorColor
                                  : AppThemeV2.textSecondary,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: AppThemeV2.textSecondary,
                          ),
                          onTap: () {
                            Navigator.pop(context); // ボトムシートを閉じる
                            _navigateToUserDetail(userName);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 支援記録入力画面に遷移
  void _navigateToUserDetail(String userName) async {
    if (widget.admin.gasUrl == null || widget.admin.gasUrl!.isEmpty) {
      _showError(context, 'GAS URLが設定されていません');
      return;
    }

    final dateStr = DateFormat(AppConstants.dateFormat).format(DateTime.now());
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserDetailScreen(
          date: dateStr,
          userName: userName,
          gasUrl: widget.admin.gasUrl!,
          staffName: widget.admin.adminName,
        ),
      ),
    );

    // 保存後はステータスを再読み込み
    if (result is Map<String, dynamic> && result['saved'] == true) {
      _loadTodayStats();
    }
  }

  /// メインメニュー
  Widget _buildMainMenu(BuildContext context) {
    return Column(
      children: [
        // 本日の勤怠一覧（メイン機能）
        _MenuCard(
          icon: Icons.today,
          title: '本日の勤怠一覧',
          subtitle: '出勤・支援記録の確認と登録',
          color: AppThemeV2.primaryGreen,
          isPrimary: true,
          onTap: () => _navigateToDailyAttendance(context),
        ),
        const SizedBox(height: 12),

        // 2列レイアウト
        Row(
          children: [
            Expanded(
              child: _MenuCard(
                icon: Icons.analytics,
                title: '統計・分析',
                subtitle: '利用状況の確認',
                color: AppThemeV2.infoColor,
                onTap: () => _navigateToAnalytics(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MenuCard(
                icon: Icons.receipt_long,
                title: '請求業務',
                subtitle: '請求データ出力',
                color: AppThemeV2.accentOrange,
                onTap: () => _navigateToBillingSettings(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _MenuCard(
                icon: Icons.people,
                title: '支援者管理',
                subtitle: 'アカウント設定',
                color: Colors.purple,
                onTap: () => _navigateToStaffManagement(context),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MenuCard(
                icon: Icons.person_add,
                title: '利用者管理',
                subtitle: 'アカウント設定',
                color: Colors.teal,
                onTap: () => _navigateToUserManagement(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 設定（フル幅）
        _MenuCard(
          icon: Icons.settings,
          title: '設定',
          subtitle: '施設情報・各種設定',
          color: Colors.grey,
          onTap: () => _navigateToSettings(context),
        ),
      ],
    );
  }

  // === ナビゲーション ===

  void _navigateToDailyAttendance(BuildContext context) {
    if (widget.admin.gasUrl == null || widget.admin.gasUrl!.isEmpty) {
      _showError(context, 'GAS URLが設定されていません');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FacilityAdminDailyAttendanceScreen(
          gasUrl: widget.admin.gasUrl!,
          facilityName: widget.admin.facilityName,
          adminName: widget.admin.adminName,
        ),
      ),
    ).then((_) {
      // 戻ってきたらステータスを再読み込み
      _loadTodayStats();
    });
  }

  void _navigateToStaffManagement(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StaffListScreen(gasUrl: widget.admin.gasUrl),
      ),
    );
  }

  void _navigateToUserManagement(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserListScreen(gasUrl: widget.admin.gasUrl),
      ),
    );
  }

  void _navigateToAnalytics(BuildContext context) {
    if (widget.admin.gasUrl == null || widget.admin.gasUrl!.isEmpty) {
      _showError(context, 'GAS URLが設定されていません');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FacilityAdminAnalyticsScreen(gasUrl: widget.admin.gasUrl),
      ),
    );
  }

  void _navigateToSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FacilityAdminSettingsScreen(
          gasUrl: widget.admin.gasUrl,
          facilityId: widget.admin.facilityId,
        ),
      ),
    );
  }

  void _navigateToBillingSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BillingSettingsScreen(
          gasUrl: widget.admin.gasUrl,
          facilityId: widget.admin.facilityId,
        ),
      ),
    );
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppThemeV2.errorColor,
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('ログアウト'),
        content: const Text('ログアウトしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppThemeV2.primaryGreen,
            ),
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      final authService = MasterAuthService();
      await authService.logoutSession();

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MenuSelectionScreen()),
        (route) => false,
      );
    }
  }
}

/// クイックステータスカード（コンパクト版）
class _QuickStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final String? description;
  final Color color;

  const _QuickStatCard({
    required this.label,
    required this.value,
    this.unit,
    this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          // ラベル
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppThemeV2.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          // 値と単位
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 1),
                Text(
                  unit!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ],
          ),
          // 説明文
          if (description != null) ...[
            const SizedBox(height: 2),
            Text(
              description!,
              style: const TextStyle(
                fontSize: 9,
                color: AppThemeV2.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );

    return card;
  }
}

/// メニューカード
class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isPrimary;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.isPrimary = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(isPrimary ? 20 : 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPrimary ? color.withOpacity(0.3) : AppThemeV2.borderColor,
              width: isPrimary ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isPrimary
                    ? color.withOpacity(0.1)
                    : Colors.black.withOpacity(0.03),
                blurRadius: isPrimary ? 12 : 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // アイコン
              Container(
                width: isPrimary ? 52 : 44,
                height: isPrimary ? 52 : 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(isPrimary ? 14 : 10),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: isPrimary ? 26 : 22,
                ),
              ),
              SizedBox(width: isPrimary ? 16 : 12),
              // テキスト
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isPrimary ? 17 : 15,
                        fontWeight: FontWeight.w600,
                        color: AppThemeV2.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: isPrimary ? 13 : 12,
                        color: AppThemeV2.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // 矢印
              Icon(
                Icons.chevron_right,
                color: AppThemeV2.textSecondary,
                size: isPrimary ? 24 : 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
