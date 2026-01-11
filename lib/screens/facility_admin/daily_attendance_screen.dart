import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/attendance.dart';
import '../../services/attendance_service.dart';
import '../../services/master_service.dart';
import '../../config/constants.dart';
import '../../widgets/health_line_chart.dart';
import '../staff/user_detail_screen.dart';

/// 施設管理者用の本日の出勤一覧画面
class FacilityAdminDailyAttendanceScreen extends StatefulWidget {
  final String gasUrl;
  final String facilityName;
  final String? adminName; // 管理者名（記録者として使用）

  const FacilityAdminDailyAttendanceScreen({
    super.key,
    required this.gasUrl,
    required this.facilityName,
    this.adminName,
  });

  @override
  State<FacilityAdminDailyAttendanceScreen> createState() =>
      _FacilityAdminDailyAttendanceScreenState();
}

class _FacilityAdminDailyAttendanceScreenState
    extends State<FacilityAdminDailyAttendanceScreen>
    with SingleTickerProviderStateMixin {
  late final AttendanceService _attendanceService;
  late final MasterService _masterService;
  List<Attendance> _attendances = [];
  List<Map<String, dynamic>> _scheduledUsers = [];
  int _totalScheduledCount = 0; // 曜日ごとの出勤予定者数（出勤済み含む）
  Map<String, List<EvaluationAlert>> _evaluationAlerts = {};
  Map<String, List<HealthDataPoint>> _healthHistory = {};
  bool _isLoading = true;
  String? _errorMessage;
  DateTime _selectedDate = DateTime.now();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _attendanceService = AttendanceService(gasUrl: widget.gasUrl);
    _masterService = MasterService(gasUrl: widget.gasUrl);
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// データを読み込む
  Future<void> _loadData() async {
    await Future.wait([
      _loadAttendances(),
      _loadScheduledUsers(),
      _loadEvaluationAlerts(),
    ]);
    // 健康履歴を非同期で読み込み
    _loadHealthBatch();
  }

  /// 日付を今日に更新してデータを再読み込み（日を跨いだ場合に対応）
  Future<void> _refreshToToday() async {
    setState(() {
      _selectedDate = DateTime.now();
    });
    await _masterService.clearUsersCache();
    await _masterService.clearDropdownCache();
    await _masterService.clearAlertsCache();
    _loadData();
  }

  /// 健康履歴をバッチで読み込む
  Future<void> _loadHealthBatch() async {
    try {
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
      // エラー時は無視
    }
  }

  /// 評価アラート情報を読み込む
  Future<void> _loadEvaluationAlerts() async {
    try {
      final alerts = await _masterService.getEvaluationAlerts();
      if (!mounted) return;
      final Map<String, List<EvaluationAlert>> groupedAlerts = {};
      for (var alert in alerts) {
        groupedAlerts.putIfAbsent(alert.userName, () => []).add(alert);
      }
      setState(() {
        _evaluationAlerts = groupedAlerts;
      });
    } catch (e) {
      // エラー時は無視
    }
  }

  /// 勤怠一覧を読み込む
  Future<void> _loadAttendances() async {
    try {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final dateStr = DateFormat(AppConstants.dateFormat).format(_selectedDate);
      final attendances = await _attendanceService.getDailyAttendance(dateStr);

      // 支援記録未登録の人を上位に並べ替え
      attendances.sort((a, b) {
        final aHasSupportRecord = a.hasSupportRecord;
        final bHasSupportRecord = b.hasSupportRecord;
        if (aHasSupportRecord != bHasSupportRecord) {
          return aHasSupportRecord ? 1 : -1;
        }
        return a.userName.compareTo(b.userName);
      });

      if (!mounted) return;
      setState(() {
        _attendances = attendances;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'データの読み込みに失敗しました\n$e';
        _isLoading = false;
      });
    }
  }

  /// 出勤予定者を読み込む
  Future<void> _loadScheduledUsers() async {
    try {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final dateStr = DateFormat(AppConstants.dateFormat).format(_selectedDate);
      final scheduledUsers = await _attendanceService.getScheduledUsers(dateStr);

      // 全予定者数を保存（クイックステータス用）
      final totalCount = scheduledUsers.length;

      // 出勤済みの人を除外し、名簿順を維持（タブ・リスト用）
      final notCheckedInUsers = scheduledUsers
          .where((u) => u['hasCheckedIn'] != true)
          .toList();

      if (!mounted) return;
      setState(() {
        _totalScheduledCount = totalCount;
        _scheduledUsers = notCheckedInUsers;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'データの読み込みに失敗しました\n$e';
        _isLoading = false;
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

  int? _extractNum(String? value) {
    if (value == null || value.isEmpty) return null;
    final match = RegExp(r'^\d+').firstMatch(value);
    return match != null ? int.tryParse(match.group(0)!) : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('本日の勤怠一覧'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDate,
            tooltip: '日付を変更',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshToToday,
            tooltip: '再読み込み（キャッシュクリア）',
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
    final dateStr =
        DateFormat(AppConstants.dateDisplayFormat).format(_selectedDate);
    final isToday =
        DateFormat(AppConstants.dateFormat).format(_selectedDate) ==
            DateFormat(AppConstants.dateFormat).format(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blue.shade50,
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
                color: Colors.blue,
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
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('再読み込み'),
            ),
          ],
        ),
      ),
    );
  }

  /// 出勤一覧
  Widget _buildAttendanceList() {
    if (_attendances.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey),
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
        return _buildAttendanceCard(_attendances[index]);
      },
    );
  }

  /// 出勤予定者一覧
  Widget _buildScheduledUsersList() {
    if (_scheduledUsers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey),
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
        return _buildScheduledUserCard(_scheduledUsers[index]);
      },
    );
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

    String timeText = '';
    if (checkinTime != null) {
      final endTime = checkoutTime ?? '未退勤';
      timeText = ' ($checkinTime - $endTime)';
    }

    return Text(
      '出欠: $status$timeText',
      style: const TextStyle(fontSize: 11),
    );
  }

  /// 評価アラートのラベルを取得
  String _getEvaluationAlertLabel(List<EvaluationAlert> alerts) {
    if (alerts.length >= 2) {
      return '評価アラート';
    }
    final alertType = alerts.first.alertType;
    if (alertType == 'external') {
      return '施設外評価アラート';
    } else if (alertType == 'home') {
      return '在宅評価アラート';
    }
    return '評価アラート';
  }

  /// コンパクトなアラート表示
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

  /// 予定者用コンパクトアラート
  Widget _buildScheduledCompactAlerts(String userName) {
    final alerts = _evaluationAlerts[userName];
    if (alerts == null || alerts.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: _buildCompactAlertChip(_getEvaluationAlertLabel(alerts), Colors.red),
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
                gasUrl: widget.gasUrl,
                staffName: widget.adminName,
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

    // 背景色とステータス
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
                gasUrl: widget.gasUrl,
                staffName: widget.adminName,
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
}
