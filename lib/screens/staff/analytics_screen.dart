import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/user.dart';
import '../../models/attendance.dart';
import '../../services/attendance_service.dart';
import '../../services/master_service.dart';
import '../../widgets/searchable_dropdown.dart';
import '../../widgets/health_line_chart.dart';
import '../../theme/app_theme_v2.dart';

/// 分析画面（支援者用・V2デザイン）
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  final MasterService _masterService = MasterService();

  bool _isLoading = true;
  String? _errorMessage;

  // 施設全体の統計
  Map<String, dynamic> _facilityStats = {};

  // 曜日別出勤予定
  Map<String, Map<String, int>> _weeklySchedule = {};
  // 曜日別出勤予定の詳細（元の値ごとのカウント）
  Map<String, Map<String, Map<String, int>>> _weeklyDetails = {};

  // 利用者一覧（個人分析用）
  List<User> _users = [];
  User? _selectedUser;
  Map<String, dynamic>? _userStats;
  List<Attendance> _userHealthHistory = [];  // 過去60回分の健康履歴
  bool _isLoadingUserStats = false;

  // 当月退所者（analytics/batchから取得）
  List<Map<String, dynamic>> _departedUsers = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // 並列でデータを読み込む
      await Future.wait([
        _loadFacilityStats(),
        _loadWeeklySchedule(),
        _loadUsers(),
      ]);

      if (!mounted) return;
      setState(() {
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

  /// 施設全体の統計を読み込む（バッチAPIで退所者も一括取得）
  Future<void> _loadFacilityStats() async {
    final batchData = await _attendanceService.getAnalyticsBatch();
    if (!mounted) return;

    // 退所者リストを取得
    final departedList = batchData['departedUsers'] as List<dynamic>? ?? [];
    final departed = departedList
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    setState(() {
      _facilityStats = batchData['facilityStats'] as Map<String, dynamic>? ?? {};
      _departedUsers = departed;
    });
  }

  /// 曜日別出勤予定を読み込む
  Future<void> _loadWeeklySchedule() async {
    final result = await _attendanceService.getWeeklyScheduleWithDetails();
    if (!mounted) return;
    setState(() {
      _weeklySchedule = result['schedule'] as Map<String, Map<String, int>>;
      _weeklyDetails = result['details'] as Map<String, Map<String, Map<String, int>>>;
    });
  }

  /// 利用者一覧を読み込む（個人分析用）
  Future<void> _loadUsers() async {
    final users = await _masterService.getActiveUsers();
    if (!mounted) return;
    setState(() {
      _users = users;
    });
  }

  /// 個人の統計を読み込む
  Future<void> _loadUserStats(String userName) async {
    try {
      setState(() {
        _isLoadingUserStats = true;
      });

      // 統計データと履歴データを並列取得
      final results = await Future.wait([
        _attendanceService.getUserStats(userName),
        _attendanceService.getUserHistory(userName),
      ]);

      if (!mounted) return;

      final allHistory = results[1] as List<Attendance>;
      // 過去60回分のみ取得（新しい順）
      final healthHistory = allHistory.take(60).toList();

      setState(() {
        _userStats = results[0] as Map<String, dynamic>;
        _userHealthHistory = healthHistory;
        _isLoadingUserStats = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _userStats = null;
        _userHealthHistory = [];
        _isLoadingUserStats = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeV2.backgroundGrey,
      appBar: AppBar(
        title: const Text('分析'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.indigo))
          : _errorMessage != null
              ? _buildErrorView()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 施設全体の統計
                        _buildFacilityStatsSection(),
                        const SizedBox(height: 24),
                        // 曜日別出勤予定
                        _buildWeeklyScheduleSection(),
                        const SizedBox(height: 24),
                        // 当月退所者
                        _buildDepartedUsersSection(),
                        const SizedBox(height: 24),
                        // 利用者個人分析
                        _buildUserAnalysisSection(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
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

  /// 施設全体の統計セクション
  Widget _buildFacilityStatsSection() {
    final totalUsers = _facilityStats['totalUsers'] ?? 0;
    final attendanceRate = _facilityStats['attendanceRate'] ?? 0.0;
    final monthlyWorkDays = _facilityStats['monthlyWorkDays'] ?? 0;
    final monthlyAttendance = _facilityStats['monthlyAttendance'] ?? 0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.business, color: Colors.indigo.shade700),
                const SizedBox(width: 8),
                Text(
                  '施設全体の統計',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade700,
                  ),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.people,
                    label: '当月利用者数',
                    value: '$totalUsers名',
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.pie_chart,
                    label: '出勤率',
                    value: '${(attendanceRate * 100).toStringAsFixed(1)}%',
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.calendar_today,
                    label: '当月稼働日数',
                    value: '$monthlyWorkDays日',
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.check_circle,
                    label: '当月出勤延べ数',
                    value: '$monthlyAttendance回',
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// 曜日別出勤予定セクション
  Widget _buildWeeklyScheduleSection() {
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    const types = ['本施設', '在宅'];  // 施設外は小計行で表示
    const typeColors = [Colors.blue, Colors.green];

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_view_week, color: Colors.indigo.shade700),
                const SizedBox(width: 8),
                Text(
                  '曜日別出勤予定',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '※ 本施設・施設外をタップで詳細表示',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
            const Divider(),
            const SizedBox(height: 8),
            // ヘッダー行
            Row(
              children: [
                const SizedBox(width: 60),
                ...weekdays.map((day) => Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                )),
              ],
            ),
            const SizedBox(height: 8),
            // 各タイプの行
            ...List.generate(types.length, (typeIndex) {
              final type = types[typeIndex];
              final color = typeColors[typeIndex];
              // 本施設と施設外のみクリック可能
              final isClickable = type == '本施設' || type == '施設外';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text(
                        type,
                        style: TextStyle(
                          fontSize: 12,
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ...weekdays.map((day) {
                      final count = _weeklySchedule[day]?[type] ?? 0;
                      final hasDetails = _weeklyDetails[day]?[type]?.isNotEmpty ?? false;

                      return Expanded(
                        child: Center(
                          child: MouseRegion(
                            cursor: (isClickable && count > 0)
                                ? SystemMouseCursors.click
                                : SystemMouseCursors.basic,
                            child: GestureDetector(
                              onTap: (isClickable && count > 0)
                                  ? () => _showScheduleDetails(day, type, color)
                                  : null,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: count > 0
                                      ? color.withValues(alpha: 0.2)
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: (isClickable && count > 0)
                                      ? Border.all(color: color, width: 2)
                                      : null,
                                ),
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: count > 0 ? color : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),
            const SizedBox(height: 4),
            const Divider(height: 1),
            const SizedBox(height: 4),
            // 施設外 行（クリック可能）
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text(
                      '施設外',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ...weekdays.map((day) {
                    final count = _weeklySchedule[day]?['施設外'] ?? 0;
                    return Expanded(
                      child: Center(
                        child: MouseRegion(
                          cursor: count > 0
                              ? SystemMouseCursors.click
                              : SystemMouseCursors.basic,
                          child: GestureDetector(
                            onTap: count > 0
                                ? () => _showScheduleDetails(day, '施設外', Colors.orange)
                                : null,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: count > 0
                                    ? Colors.orange.withValues(alpha: 0.2)
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: count > 0
                                    ? Border.all(color: Colors.orange, width: 2)
                                    : null,
                              ),
                              child: Text(
                                '$count',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: count > 0 ? Colors.orange : Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 4),
            const Divider(height: 1),
            const SizedBox(height: 4),
            // 合計行
            Row(
              children: [
                const SizedBox(
                  width: 60,
                  child: Text(
                    '合計',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...weekdays.map((day) {
                  final total = (_weeklySchedule[day]?['本施設'] ?? 0) +
                      (_weeklySchedule[day]?['在宅'] ?? 0) +
                      (_weeklySchedule[day]?['施設外'] ?? 0);
                  return Expanded(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$total',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo.shade700,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 出勤予定の詳細をダイアログで表示
  void _showScheduleDetails(String weekday, String type, Color color) {
    final details = _weeklyDetails[weekday]?[type] ?? {};
    if (details.isEmpty) return;

    // 詳細を件数の多い順にソート
    final sortedEntries = details.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: color),
            const SizedBox(width: 8),
            Text(
              '$weekday曜日 - $type',
              style: TextStyle(color: color, fontSize: 18),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: sortedEntries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${entry.value}名',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  /// 当月退所者セクション
  Widget _buildDepartedUsersSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_off, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Text(
                  '退所者一覧',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_departedUsers.length}名',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),
            if (_departedUsers.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    '退所者はいません',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ...(_departedUsers.take(5).map((user) {
                final userName = user['userName']?.toString() ?? '';
                final leaveDate = user['leaveDate']?.toString() ?? '';
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.red.shade100,
                    child: Text(
                      userName.isNotEmpty ? userName.substring(0, 1) : '?',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                  title: Text(userName),
                  subtitle: Text('退所日: $leaveDate'),
                  dense: true,
                );
              })),
            if (_departedUsers.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: Text(
                    '他 ${_departedUsers.length - 5}名',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 利用者個人分析セクション
  Widget _buildUserAnalysisSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_search, color: Colors.indigo.shade700),
                const SizedBox(width: 8),
                Text(
                  '利用者個人分析',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade700,
                  ),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            // 利用者選択
            SearchableDropdown<User>(
              value: _selectedUser,
              items: _users,
              itemLabel: (user) => user.name,
              onChanged: (user) {
                setState(() {
                  _selectedUser = user;
                  _userStats = null;
                });
                if (user != null) {
                  _loadUserStats(user.name);
                }
              },
              hint: '利用者を選択...',
            ),
            const SizedBox(height: 16),
            // 個人統計表示
            if (_selectedUser != null) _buildUserStatsContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildUserStatsContent() {
    if (_isLoadingUserStats) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_userStats == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('統計データがありません', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    final attendanceRate = _userStats!['attendanceRate'] ?? 0.0;
    final totalWorkMinutes = _userStats!['totalWorkMinutes'] ?? 0;
    final avgWorkMinutes = _userStats!['avgWorkMinutes'] ?? 0;
    final attendanceDays = _userStats!['attendanceDays'] ?? 0;
    final absentDays = _userStats!['absentDays'] ?? 0;

    final totalHours = (totalWorkMinutes / 60).floor();
    final totalMins = totalWorkMinutes % 60;
    final avgHours = (avgWorkMinutes / 60).floor();
    final avgMins = avgWorkMinutes % 60;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.pie_chart,
                label: '出勤率',
                value: '${(attendanceRate * 100).toStringAsFixed(1)}%',
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.timer,
                label: '平均勤務時間',
                value: '${avgHours}h${avgMins}m',
                color: Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.check_circle,
                label: '出勤日数',
                value: '$attendanceDays日',
                color: Colors.teal,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                icon: Icons.cancel,
                label: '欠勤日数',
                value: '$absentDays日',
                color: Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple.shade200),
          ),
          child: Column(
            children: [
              Icon(Icons.access_time, color: Colors.purple.shade700, size: 28),
              const SizedBox(height: 8),
              Text(
                '当月合計勤務時間',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${totalHours}時間${totalMins}分',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade700,
                ),
              ),
            ],
          ),
        ),
        // 健康グラフセクション
        if (_userHealthHistory.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.show_chart, color: Colors.orange.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                '健康推移（過去${_userHealthHistory.length}回分）',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '※ グラフをタップで詳細表示',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 12),
          // 健康グラフ 2x2
          _buildHealthChartsGrid(),
        ],
      ],
    );
  }

  /// 健康グラフの2x2グリッド
  Widget _buildHealthChartsGrid() {
    // グラフ表示用に古い順に並べ替え
    final sortedHistory = _userHealthHistory.reversed.toList();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildHealthChartCard(
                sortedHistory,
                HealthMetricType.healthCondition,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildHealthChartCard(
                sortedHistory,
                HealthMetricType.sleepStatus,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildHealthChartCard(
                sortedHistory,
                HealthMetricType.fatigue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildHealthChartCard(
                sortedHistory,
                HealthMetricType.stress,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 個別の健康グラフカード
  Widget _buildHealthChartCard(
    List<Attendance> history,
    HealthMetricType type,
  ) {
    final dataPoints = extractHealthData(history, type);

    return HealthLineChartCard(
      dataPoints: dataPoints,
      type: type,
      onTap: () => _showFullScreenHealthChart(type),
    );
  }

  /// 全画面健康グラフ表示
  void _showFullScreenHealthChart(HealthMetricType type) {
    // 古い順に並べ替え
    final sortedHistory = _userHealthHistory.reversed.toList();
    final dataPoints = extractHealthData(sortedHistory, type);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenHealthChart(
          dataPoints: dataPoints,
          type: type,
          userName: _selectedUser?.name ?? '',
        ),
      ),
    );
  }
}

/// 全画面健康グラフ
class FullScreenHealthChart extends StatelessWidget {
  final List<HealthDataPoint> dataPoints;
  final HealthMetricType type;
  final String userName;

  const FullScreenHealthChart({
    super.key,
    required this.dataPoints,
    required this.type,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    final validPoints = dataPoints.where((p) => p.value != null).toList();
    final average = validPoints.isNotEmpty
        ? validPoints.map((p) => p.value!).reduce((a, b) => a + b) / validPoints.length
        : null;
    final maxValue = validPoints.isNotEmpty
        ? validPoints.map((p) => p.value!).reduce((a, b) => a > b ? a : b)
        : null;
    final minValue = validPoints.isNotEmpty
        ? validPoints.map((p) => p.value!).reduce((a, b) => a < b ? a : b)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text('$userName - ${type.title}'),
        backgroundColor: type.color,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 統計情報
          if (average != null)
            Container(
              padding: const EdgeInsets.all(16),
              color: type.color.withValues(alpha: 0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('平均', average.toStringAsFixed(1)),
                  _buildStatItem('最高', maxValue?.toString() ?? '--'),
                  _buildStatItem('最低', minValue?.toString() ?? '--'),
                  _buildStatItem('件数', '${validPoints.length}'),
                ],
              ),
            ),
          // グラフ
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: validPoints.isEmpty
                  ? const Center(child: Text('データがありません'))
                  : _buildChart(validPoints),
            ),
          ),
          // 履歴一覧
          const Divider(height: 1),
          Expanded(
            flex: 2,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: dataPoints.length,
              itemBuilder: (context, index) {
                final point = dataPoints[dataPoints.length - 1 - index]; // 新しい順
                return _buildHistoryItem(point, index == 0);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(List<HealthDataPoint> validPoints) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            // データ数に応じて幅を調整（最小でも画面幅）
            width: validPoints.length > 15
                ? validPoints.length * 25.0
                : constraints.maxWidth,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                    );
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                      color: Colors.grey.shade200,
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: validPoints.length > 30 ? 5 : (validPoints.length > 15 ? 2 : 1),
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < validPoints.length) {
                          final date = validPoints[index].date;
                          final parts = date.split('/');
                          if (parts.length >= 3) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '${parts[1]}/${parts[2]}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            );
                          }
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        if (value >= 1 && value <= 10 && value == value.roundToDouble()) {
                          return Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.grey.shade300),
                ),
                clipData: const FlClipData.all(),
                minY: 1,
                maxY: 10,
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final index = spot.x.toInt();
                        if (index >= 0 && index < validPoints.length) {
                          final point = validPoints[index];
                          return LineTooltipItem(
                            '${point.date}\n${point.label ?? point.value}',
                            const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          );
                        }
                        return null;
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: validPoints.asMap().entries.map((entry) {
                      return FlSpot(
                        entry.key.toDouble(),
                        entry.value.value!.toDouble(),
                      );
                    }).toList(),
                    isCurved: false,
                    color: type.color,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: validPoints.length <= 30,
                      getDotPainter: (spot, percent, bar, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: type.color,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: type.color.withValues(alpha: 0.2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: type.color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryItem(HealthDataPoint point, bool isLatest) {
    final hasValue = point.value != null;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Row(
        children: [
          // 日付
          SizedBox(
            width: 100,
            child: Text(
              point.date,
              style: TextStyle(
                fontSize: 13,
                color: isLatest ? type.color : Colors.grey.shade700,
                fontWeight: isLatest ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          // 値
          Expanded(
            child: Text(
              point.label ?? '--',
              style: TextStyle(
                fontSize: 14,
                color: hasValue ? Colors.black87 : Colors.grey.shade400,
              ),
            ),
          ),
          // インジケーター
          if (hasValue)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _getValueColor(point.value!).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Text(
                '${point.value}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _getValueColor(point.value!),
                ),
              ),
            ),
          if (isLatest)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: type.color,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '最新',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getValueColor(int value) {
    if (type.higherIsBetter) {
      if (value >= 4) return Colors.green;
      if (value >= 3) return Colors.orange;
      return Colors.red;
    } else {
      if (value <= 2) return Colors.green;
      if (value <= 3) return Colors.orange;
      return Colors.red;
    }
  }
}
