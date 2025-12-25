import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/attendance.dart';
import '../../services/attendance_service.dart';
import '../../services/auth_service.dart';
import '../../services/master_service.dart';
import '../../config/constants.dart';
import '../../widgets/health_line_chart.dart';
import '../common/menu_selection_screen.dart';
import 'user_list_screen.dart';
import 'user_detail_screen.dart';
import 'past_records_screen.dart';

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
  Map<String, EvaluationAlert> _evaluationAlerts = {}; // 利用者名→アラート情報
  Map<String, List<HealthDataPoint>> _healthHistory = {}; // 利用者名→健康履歴
  bool _isLoading = true;
  String? _errorMessage;
  DateTime _selectedDate = DateTime.now();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 勤怠一覧と出勤予定者を読み込む
  Future<void> _loadData() async {
    await Future.wait([
      _loadAttendances(),
      _loadScheduledUsers(),
      _loadEvaluationAlerts(),
    ]);
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
      setState(() {
        _evaluationAlerts = {for (var alert in alerts) alert.userName: alert};
      });
    } catch (e) {
      // エラー時は無視（アラートが表示されないだけ）
    }
  }

  /// 勤怠一覧を読み込む
  Future<void> _loadAttendances() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final dateStr = DateFormat(AppConstants.dateFormat).format(_selectedDate);
      final attendances = await _attendanceService.getDailyAttendance(dateStr);

      // 退勤未登録の人を上位に並べ替え
      attendances.sort((a, b) {
        final aHasCheckout = a.checkoutTime != null;
        final bHasCheckout = b.checkoutTime != null;

        // 両方未退勤または両方退勤済みの場合は名前順
        if (aHasCheckout == bHasCheckout) {
          return a.userName.compareTo(b.userName);
        }

        // 未退勤(checkoutTime == null)を上位に
        return aHasCheckout ? 1 : -1;
      });

      setState(() {
        _attendances = attendances;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'データの読み込みに失敗しました\n$e';
        _isLoading = false;
      });
    }
  }

  /// 出勤予定者を読み込む
  Future<void> _loadScheduledUsers() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final dateStr = DateFormat(AppConstants.dateFormat).format(_selectedDate);
      final scheduledUsers = await _attendanceService.getScheduledUsers(dateStr);

      setState(() {
        _scheduledUsers = scheduledUsers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'データの読み込みに失敗しました\n$e';
        _isLoading = false;
      });
    }
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
      // 認証情報をクリア
      await _authService.clearLoginCredentials();
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
      appBar: AppBar(
        title: Text('本日の出勤一覧 - ${widget.staffName}'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDate,
            tooltip: '日付を変更',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: '再読み込み',
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
          tabs: const [
            Tab(text: '出勤一覧'),
            Tab(text: '出勤予定者'),
          ],
        ),
      ),
      drawer: _buildDrawer(),
      body: Column(
        children: [
          _buildDateDisplay(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
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
              ),
            ),
          );
          if (result == true) {
            _loadData();
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
    final hasEvaluationAlert = _evaluationAlerts.containsKey(userName);

    if (!hasEvaluationAlert) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: _buildCompactAlertChip('評価アラート', Colors.red),
    );
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
              ),
            ),
          );
          if (result == true) {
            _loadData();
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
    final hasEvaluationAlert = _evaluationAlerts.containsKey(attendance.userName);

    final alerts = <Widget>[];

    if (!hasSupportRecord) {
      alerts.add(_buildCompactAlertChip('支援記録未登録', Colors.purple));
    }
    if (hasComment) {
      alerts.add(_buildCompactAlertChip('コメント有', Colors.orange));
    }
    if (hasEvaluationAlert) {
      alerts.add(_buildCompactAlertChip('評価アラート', Colors.red));
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
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
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

  /// ドロワーメニュー
  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Colors.orange,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.business_center,
                  color: Colors.white,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.staffName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  '支援者メニュー',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.event_available),
            title: const Text('本日の出勤一覧'),
            selected: true,
            selectedTileColor: Colors.orange.shade50,
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
}
