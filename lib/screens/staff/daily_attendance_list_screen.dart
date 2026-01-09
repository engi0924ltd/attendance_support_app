import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/attendance.dart';
import '../../services/attendance_service.dart';
import '../../services/auth_service.dart';
import '../../services/master_service.dart';
import '../../config/constants.dart';
import '../../widgets/health_line_chart.dart';
import '../../theme/app_theme_v2.dart';
import '../common/menu_selection_screen.dart';
import '../common/tasks_settings_screen.dart';
import 'user_list_screen.dart';
import 'user_detail_screen.dart';
import 'past_records_screen.dart';
import 'chatwork_broadcast_screen.dart';
import 'analytics_screen.dart';

/// 本日の出勤一覧画面（支援者用）
class DailyAttendanceListScreen extends StatefulWidget {
  final String staffName;

  const DailyAttendanceListScreen({
    super.key,
    required this.staffName,
  });

  @override
  State<DailyAttendanceListScreen> createState() =>
      _DailyAttendanceListScreenState();
}

class _DailyAttendanceListScreenState extends State<DailyAttendanceListScreen>
    with SingleTickerProviderStateMixin {
  final AttendanceService _attendanceService = AttendanceService();
  final AuthService _authService = AuthService();
  final MasterService _masterService = MasterService();
  List<Attendance> _attendances = [];
  List<Map<String, dynamic>> _scheduledUsers = [];
  List<Map<String, dynamic>> _notRegisteredUsers = []; // 支援記録未登録の利用者リスト
  Map<String, List<EvaluationAlert>> _evaluationAlerts = {}; // 利用者名→アラート情報リスト
  Map<String, List<HealthDataPoint>> _healthHistory = {}; // 利用者名→健康履歴
  List<Map<String, dynamic>> _certificateAlerts = []; // 受給者証期限切れアラート
  bool _isLoadingAlerts = true;
  bool _isLoading = true;
  String? _errorMessage;
  DateTime _selectedDate = DateTime.now();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
    _loadCertificateAlerts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 勤怠一覧と出勤予定者を読み込む
  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Future.wait([
        _loadAttendances(),
        _loadScheduledUsers(),
        _loadEvaluationAlerts(),
      ]);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
    // 健康履歴を非同期で読み込み（UI表示をブロックしない）
    _loadHealthBatch();
  }

  /// 健康履歴をバッチで読み込む
  Future<void> _loadHealthBatch() async {
    try {
      // 出勤者と予定者のユーザー名を収集
      final userNames = <String>{};
      for (final a in _attendances) {
        userNames.add(a.userName);
      }
      for (final s in _scheduledUsers) {
        final userName = s['userName'] as String?;
        if (userName != null) {
          userNames.add(userName);
        }
      }

      if (userNames.isEmpty) return;

      final batchData = await _attendanceService.getHealthBatch(userNames.toList());

      // 健康データをHealthDataPointに変換
      final healthHistory = <String, List<HealthDataPoint>>{};
      batchData.forEach((userName, records) {
        healthHistory[userName] = records.map((r) {
          final healthValue = r['healthCondition'] as String?;
          return HealthDataPoint(
            date: r['date'] as String? ?? '',
            value: _extractNum(healthValue),
            label: healthValue,
          );
        }).toList();
      });

      if (mounted) {
        setState(() {
          _healthHistory = healthHistory;
        });
      }
    } catch (e) {
      // エラー時は無視（グラフが表示されないだけ）
    }
  }

  /// 評価アラート情報を読み込む
  Future<void> _loadEvaluationAlerts() async {
    try {
      final alerts = await _masterService.getEvaluationAlerts();
      if (!mounted) return;
      // 同一ユーザーの複数アラートをグループ化
      final Map<String, List<EvaluationAlert>> groupedAlerts = {};
      for (var alert in alerts) {
        groupedAlerts.putIfAbsent(alert.userName, () => []).add(alert);
      }
      setState(() {
        _evaluationAlerts = groupedAlerts;
      });
    } catch (e) {
      // エラー時は無視（アラートが表示されないだけ）
    }
  }

  /// 受給者証期限切れアラートを読み込む
  Future<void> _loadCertificateAlerts() async {
    try {
      final alerts = await _attendanceService.getCertificateAlerts();
      if (mounted) {
        setState(() {
          _certificateAlerts = alerts;
          _isLoadingAlerts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingAlerts = false;
        });
      }
    }
  }

  /// 勤怠一覧を読み込む
  Future<void> _loadAttendances() async {
    try {
      if (!mounted) return;

      final dateStr = DateFormat(AppConstants.dateFormat).format(_selectedDate);
      final attendances = await _attendanceService.getDailyAttendance(dateStr);

      // 支援記録未登録の人を上位に並べ替え
      attendances.sort((a, b) {
        final aHasSupportRecord = a.hasSupportRecord;
        final bHasSupportRecord = b.hasSupportRecord;

        // 支援記録未登録を上位に
        if (aHasSupportRecord != bHasSupportRecord) {
          return aHasSupportRecord ? 1 : -1;
        }

        // 同じ状態の場合は名前順
        return a.userName.compareTo(b.userName);
      });

      // 支援記録未登録の利用者リストを作成
      final notRegisteredUsers = attendances
          .where((a) => !a.hasSupportRecord)
          .map((a) => {
                'userName': a.userName,
                'status': a.attendanceStatus ?? '出勤',
                'attendance': a,
              })
          .toList();

      if (!mounted) return;
      setState(() {
        _attendances = attendances;
        _notRegisteredUsers = notRegisteredUsers;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'データの読み込みに失敗しました\n$e';
      });
    }
  }

  /// 出勤予定者を読み込む
  Future<void> _loadScheduledUsers() async {
    try {
      if (!mounted) return;

      final dateStr = DateFormat(AppConstants.dateFormat).format(_selectedDate);
      final scheduledUsers = await _attendanceService.getScheduledUsers(dateStr);

      // 出勤済みの人を除外し、名簿順を維持
      final notCheckedInUsers = scheduledUsers
          .where((u) => u['hasCheckedIn'] != true)
          .toList();

      if (!mounted) return;
      setState(() {
        _scheduledUsers = notCheckedInUsers;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'データの読み込みに失敗しました\n$e';
      });
    }
  }

  /// 保存結果を受け取ってローカル状態を更新
  void _updateLocalState(Map<String, dynamic> result) {
    final userName = result['userName'] as String?;
    final hasSupportRecord = result['hasSupportRecord'] as bool? ?? false;

    if (userName == null) return;

    setState(() {
      // 出勤一覧を更新
      for (int i = 0; i < _attendances.length; i++) {
        if (_attendances[i].userName == userName) {
          _attendances[i] = _attendances[i].copyWith(hasSupportRecord: hasSupportRecord);
          break;
        }
      }

      // 出勤予定者一覧を更新
      for (int i = 0; i < _scheduledUsers.length; i++) {
        if (_scheduledUsers[i]['userName'] == userName) {
          final attendance = _scheduledUsers[i]['attendance'] as Attendance?;
          if (attendance != null) {
            _scheduledUsers[i]['attendance'] = attendance.copyWith(hasSupportRecord: hasSupportRecord);
          }
          break;
        }
      }
    });

    // バックグラウンドでデータを再取得（UIをブロックしない）
    Future.delayed(const Duration(milliseconds: 100), () {
      _loadData();
    });
  }

  /// 記録未登録の利用者一覧を表示
  void _showNotRegisteredUsers() {
    final dateStr = DateFormat(AppConstants.dateFormat).format(_selectedDate);

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
                            // ユーザー詳細画面へ遷移
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => UserDetailScreen(
                                  date: dateStr,
                                  userName: userName,
                                  staffName: widget.staffName,
                                ),
                              ),
                            ).then((result) {
                              if (result is Map<String, dynamic>) {
                                _updateLocalState(result);
                              }
                            });
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

  /// 日付を変更
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadData();
    }
  }

  /// ログアウト処理
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

    if (confirm == true) {
      // セッション情報のみクリア（保存した認証情報は維持）
      await _authService.logout();

      if (mounted) {
        // すべての画面を削除して、新しいメニュー選択画面を作成
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const MenuSelectionScreen(),
          ),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeV2.backgroundGrey,
      appBar: AppBar(
        title: Text('本日の出勤一覧 - ${widget.staffName}'),
        backgroundColor: AppThemeV2.accentOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDate,
            tooltip: '日付を変更',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              // 全キャッシュをクリアしてから再読み込み
              await _masterService.clearUsersCache();
              await _masterService.clearDropdownCache();
              await _masterService.clearAlertsCache();
              _loadData();
            },
            tooltip: '再読み込み（キャッシュクリア）',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'ログアウト',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(text: '出勤一覧（${_attendances.length}）'),
            Tab(text: '出勤予定者（${_scheduledUsers.length}）'),
          ],
        ),
      ),
      drawer: _buildDrawer(),
      body: Column(
        children: [
          _buildDateDisplay(),
          // 受給者証期限切れアラート
          if (!_isLoadingAlerts && _certificateAlerts.isNotEmpty)
            _buildCertificateAlert(),
          // V2: クイックステータス
          _buildQuickStats(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppThemeV2.accentOrange))
                : _errorMessage != null
                    ? _buildErrorView()
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildAttendanceList(),
                          _buildScheduledUsersList(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  /// V2: クイックステータス表示
  Widget _buildQuickStats() {
    // 出勤予定数
    final scheduled = _scheduledUsers.length;
    // 出勤済み数（実際に出勤登録した人数）
    final checkedIn = _attendances.length;
    // 未出勤数（予定者のうちまだ出勤していない人）
    final notCheckedIn = _scheduledUsers.where((u) => u['hasCheckedIn'] != true).length;
    // 支援記録未登録数
    final notRegistered = _attendances.where((a) => !a.hasSupportRecord).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.white,
      child: Column(
        children: [
          // ヘッダー行（タイトル + 更新ボタン）
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: AppThemeV2.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    '本日のステータス',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppThemeV2.textSecondary,
                    ),
                  ),
                ],
              ),
              // 更新ボタン
              GestureDetector(
                onTap: _isLoading ? null : _loadData,
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppThemeV2.accentOrange,
                        ),
                      )
                    : Icon(
                        Icons.refresh,
                        size: 20,
                        color: AppThemeV2.accentOrange,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ステータスカード行
          Row(
            children: [
              Expanded(
                child: _QuickStatCard(
                  label: '出勤予定',
                  value: '$scheduled',
                  unit: '名',
                  color: AppThemeV2.infoColor,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _QuickStatCard(
                  label: '出勤済',
                  value: '$checkedIn',
                  unit: '名',
                  color: AppThemeV2.primaryGreen,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _QuickStatCard(
                  label: '未出勤',
                  value: '$notCheckedIn',
                  unit: '名',
                  color: notCheckedIn > 0 ? AppThemeV2.errorColor : AppThemeV2.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: GestureDetector(
                  onTap: _showNotRegisteredUsers,
                  behavior: HitTestBehavior.opaque,
                  child: _QuickStatCard(
                    label: '記録未',
                    value: '$notRegistered',
                    unit: '名',
                    color: notRegistered > 0 ? AppThemeV2.accentOrange : AppThemeV2.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 日付表示
  Widget _buildDateDisplay() {
    final dateStr = DateFormat(AppConstants.dateDisplayFormat).format(_selectedDate);
    final isToday = DateFormat(AppConstants.dateFormat).format(_selectedDate) ==
        DateFormat(AppConstants.dateFormat).format(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.orange.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            dateStr,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (isToday) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '本日',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// エラー表示
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadAttendances,
              icon: const Icon(Icons.refresh),
              label: const Text('再読み込み'),
            ),
          ],
        ),
      ),
    );
  }

  /// 出勤予定者一覧
  Widget _buildScheduledUsersList() {
    if (_scheduledUsers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'この日の出勤予定者はいません',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _scheduledUsers.length,
      itemBuilder: (context, index) {
        final scheduledUser = _scheduledUsers[index];
        return _buildScheduledUserCard(scheduledUser);
      },
    );
  }

  /// 勤怠一覧
  Widget _buildAttendanceList() {
    if (_attendances.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'この日の出勤記録はありません',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _attendances.length,
      itemBuilder: (context, index) {
        final attendance = _attendances[index];
        return _buildAttendanceCard(attendance);
      },
    );
  }

  /// 出勤予定者カード（2カラムレイアウト：左に情報、右にグラフ）
  Widget _buildScheduledUserCard(Map<String, dynamic> scheduledUser) {
    final userName = scheduledUser['userName'] as String;
    final scheduledAttendance = scheduledUser['scheduledAttendance'] as String;
    final hasCheckedIn = scheduledUser['hasCheckedIn'] as bool;
    final attendance = scheduledUser['attendance'] as Attendance?;
    final healthData = _healthHistory[userName] ?? [];

    // 状態判定
    final bool hasNotCheckedIn = !hasCheckedIn;
    final bool hasNotCheckedOut = attendance != null &&
        attendance.checkinTime != null &&
        attendance.checkoutTime == null;
    final bool hasComment = attendance != null &&
        (attendance.checkinComment != null || attendance.checkoutComment != null);

    // 背景色の優先順位：未登録 > 未退勤 > コメント
    Color? cardColor;
    IconData statusIcon;
    Color statusIconColor;
    String statusText;

    if (hasNotCheckedIn) {
      cardColor = Colors.orange.shade50;
      statusIcon = Icons.warning_amber;
      statusIconColor = Colors.orange;
      statusText = 'まだ出勤登録されていません';
    } else if (hasNotCheckedOut) {
      cardColor = Colors.yellow.shade50;
      statusIcon = Icons.check_circle;
      statusIconColor = Colors.green;
      statusText = '出勤登録済み（未退勤）';
    } else if (hasComment) {
      cardColor = Colors.blue.shade50;
      statusIcon = Icons.check_circle;
      statusIconColor = Colors.green;
      statusText = '出勤・退勤完了（コメントあり）';
    } else {
      cardColor = Colors.white;
      statusIcon = Icons.check_circle;
      statusIconColor = Colors.green;
      statusText = '出勤・退勤完了';
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      color: cardColor,
      child: InkWell(
        onTap: () async {
          final dateStr = DateFormat(AppConstants.dateFormat).format(_selectedDate);
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserDetailScreen(
                date: dateStr,
                userName: userName,
                staffName: widget.staffName,
              ),
            ),
          );
          // 保存結果を受け取ってローカル状態を即時更新
          if (result is Map<String, dynamic> && result['saved'] == true) {
            _updateLocalState(result);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              // 左側：ステータスアイコン + 情報（半分）
              Expanded(
                flex: 1,
                child: Row(
                  children: [
                    Icon(statusIcon, color: statusIconColor, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  userName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(scheduledAttendance, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(statusText, style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
                          if (attendance != null) ...[
                            _buildAttendanceStatusText(attendance),
                            _buildCompactAlerts(attendance),
                          ],
                          if (attendance == null) _buildScheduledCompactAlerts(userName),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // 中央の区切り線
              Container(
                width: 1,
                height: 60,
                color: Colors.grey.shade300,
                margin: const EdgeInsets.symmetric(horizontal: 6),
              ),
              // 右側：本日の体調グラフ（半分）
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: MiniHealthLineChart(
                    dataPoints: healthData,
                    type: HealthMetricType.healthCondition,
                    height: 60,
                    width: 130,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  /// 予定者用コンパクトアラート（出勤前）
  Widget _buildScheduledCompactAlerts(String userName) {
    final alerts = _evaluationAlerts[userName];
    if (alerts == null || alerts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: _buildCompactAlertChip(_getEvaluationAlertLabel(alerts), Colors.red),
    );
  }

  /// 評価アラートのラベルを取得
  String _getEvaluationAlertLabel(List<EvaluationAlert> alerts) {
    if (alerts.length >= 2) {
      // 両方のアラートがある場合
      return '評価アラート';
    }
    // 1つのみの場合、種類に応じて表示
    final alertType = alerts.first.alertType;
    if (alertType == 'external') {
      return '施設外評価アラート';
    } else if (alertType == 'home') {
      return '在宅評価アラート';
    }
    return '評価アラート';
  }

  /// 勤怠カード（2カラムレイアウト：左に情報、右にグラフ）
  Widget _buildAttendanceCard(Attendance attendance) {
    final hasComment = attendance.checkinComment != null || attendance.checkoutComment != null;
    final hasNotCheckedOut = attendance.checkinTime != null && attendance.checkoutTime == null;
    final healthData = _healthHistory[attendance.userName] ?? [];

    // 背景色の優先順位：未退勤 > コメント
    Color? cardColor;
    if (hasNotCheckedOut) {
      cardColor = Colors.yellow.shade50;
    } else if (hasComment) {
      cardColor = Colors.blue.shade50;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      color: cardColor,
      child: InkWell(
        onTap: () async {
          final dateStr = DateFormat(AppConstants.dateFormat).format(_selectedDate);
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserDetailScreen(
                date: dateStr,
                userName: attendance.userName,
                staffName: widget.staffName,
              ),
            ),
          );
          // 保存結果を受け取ってローカル状態を即時更新
          if (result is Map<String, dynamic> && result['saved'] == true) {
            _updateLocalState(result);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              // 左側：アバター + 情報（半分）
              Expanded(
                flex: 1,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: _getStatusColor(attendance.attendanceStatus),
                      child: Text(
                        attendance.userName.isNotEmpty ? attendance.userName.substring(0, 1) : '?',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  attendance.userName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (hasNotCheckedOut) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.yellow.shade700,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: const Text('未退勤', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                ),
                              ],
                              if (hasComment)
                                const Padding(
                                  padding: EdgeInsets.only(left: 3),
                                  child: Icon(Icons.comment, size: 12, color: Colors.orange),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          _buildAttendanceStatusText(attendance),
                          _buildCompactAlerts(attendance),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // 中央の区切り線
              Container(
                width: 1,
                height: 60,
                color: Colors.grey.shade300,
                margin: const EdgeInsets.symmetric(horizontal: 6),
              ),
              // 右側：本日の体調グラフ（半分）
              Expanded(
                flex: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: MiniHealthLineChart(
                    dataPoints: healthData,
                    type: HealthMetricType.healthCondition,
                    height: 60,
                    width: 130,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  /// コンパクトなアラート表示（カード用）
  Widget _buildCompactAlerts(Attendance attendance) {
    final hasComment = attendance.checkinComment != null || attendance.checkoutComment != null;
    final hasSupportRecord = attendance.hasSupportRecord;
    final evaluationAlerts = _evaluationAlerts[attendance.userName];

    final alerts = <Widget>[];

    if (!hasSupportRecord) {
      alerts.add(_buildCompactAlertChip('支援記録未登録', Colors.purple));
    }
    if (hasComment) {
      alerts.add(_buildCompactAlertChip('コメント有', Colors.orange));
    }
    if (evaluationAlerts != null && evaluationAlerts.isNotEmpty) {
      alerts.add(_buildCompactAlertChip(_getEvaluationAlertLabel(evaluationAlerts), Colors.red));
    }

    if (alerts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 2,
        children: alerts,
      ),
    );
  }

  Widget _buildCompactAlertChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  int? _extractNum(String? value) {
    if (value == null || value.isEmpty) return null;
    final match = RegExp(r'^\d+').firstMatch(value);
    return match != null ? int.tryParse(match.group(0)!) : null;
  }

  /// 出欠状態に応じた色
  Color _getStatusColor(String? status) {
    switch (status) {
      case '出勤':
        return Colors.green;
      case '欠勤':
        return Colors.red;
      case '遅刻':
        return Colors.orange;
      case '早退':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  /// 出欠状態と勤務時刻を表示するテキスト
  Widget _buildAttendanceStatusText(Attendance attendance) {
    final status = attendance.attendanceStatus ?? "未入力";
    final checkinTime = attendance.checkinTime;
    final checkoutTime = attendance.checkoutTime;

    // 勤務時刻の表示文字列を構築
    String timeText = '';
    if (checkinTime != null) {
      final startTime = checkinTime;
      final endTime = checkoutTime ?? '未退勤';
      timeText = ' ($startTime - $endTime)';
    } else if (checkoutTime != null) {
      // 出勤時刻がないが退勤時刻がある場合（通常はあり得ないが念のため）
      timeText = ' (--:-- - $checkoutTime)';
    }

    return Text('出欠: $status$timeText');
  }

  /// ドロワーメニュー（V2デザイン）
  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: AppThemeV2.accentOrange,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.business_center,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.staffName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  '支援者メニュー',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.event_available, color: AppThemeV2.accentOrange),
            title: const Text('本日の出勤一覧'),
            selected: true,
            selectedTileColor: AppThemeV2.accentOrange.withValues(alpha: 0.1),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('利用者管理'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UserListScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.analytics, color: Colors.indigo),
            title: const Text('分析'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AnalyticsScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('過去の実績記録'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PastRecordsScreen(
                    staffName: widget.staffName,
                  ),
                ),
              );
            },
          ),
          // チャットワーク連絡セクション
          const Padding(
            padding: EdgeInsets.only(left: 16, top: 8, bottom: 4),
            child: Text(
              'チャットワーク連絡',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.campaign, color: Colors.red),
            title: const Text('一斉送信'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChatworkBroadcastScreen(
                    mode: ChatworkSendMode.broadcast,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_search, color: Colors.red),
            title: const Text('選択送信'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChatworkBroadcastScreen(
                    mode: ChatworkSendMode.selective,
                  ),
                ),
              );
            },
          ),
          // 設定セクション
          const Padding(
            padding: EdgeInsets.only(left: 16, top: 8, bottom: 4),
            child: Text(
              '設定',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.work_outline, color: Colors.orange),
            title: const Text('作業登録・編集'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TasksSettingsScreen(),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('ログアウト', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _logout();
            },
          ),
        ],
      ),
    );
  }

  /// 受給者証期限切れアラートカード
  Widget _buildCertificateAlert() {
    return GestureDetector(
      onTap: _showCertificateAlerts,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        padding: const EdgeInsets.all(12),
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
                color: AppThemeV2.errorColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppThemeV2.errorColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '受給者証の期限切れ（${_certificateAlerts.length}名）',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppThemeV2.errorColor,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'タップして詳細を確認',
                    style: TextStyle(
                      color: AppThemeV2.errorColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppThemeV2.errorColor,
            ),
          ],
        ),
      ),
    );
  }

  /// 受給者証期限切れアラートのボトムシート表示
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
                color: Colors.grey[300],
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
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: AppThemeV2.errorColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '受給者証の期限切れ（${_certificateAlerts.length}名）',
                    style: const TextStyle(
                      fontSize: 18,
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
}

/// V2: クイックステータスカード
class _QuickStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final Color color;

  const _QuickStatCard({
    required this.label,
    required this.value,
    this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (unit != null)
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Text(
                    unit!,
                    style: TextStyle(
                      fontSize: 10,
                      color: color,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
