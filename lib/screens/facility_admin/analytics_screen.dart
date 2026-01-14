import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/user.dart';
import '../../models/attendance.dart';
import '../../services/attendance_service.dart';
import '../../services/master_service.dart';
import '../../widgets/searchable_dropdown.dart';
import '../../widgets/health_line_chart.dart';

/// 分析画面（施設管理者用）
class FacilityAdminAnalyticsScreen extends StatefulWidget {
  final String? gasUrl;

  const FacilityAdminAnalyticsScreen({
    super.key,
    this.gasUrl,
  });

  @override
  State<FacilityAdminAnalyticsScreen> createState() => _FacilityAdminAnalyticsScreenState();
}

class _FacilityAdminAnalyticsScreenState extends State<FacilityAdminAnalyticsScreen> {
  late final AttendanceService _attendanceService;
  late final MasterService _masterService;

  bool _isLoading = true;
  String? _errorMessage;

  // 選択中の月（nullは当月）
  DateTime _selectedMonth = DateTime.now();

  // 施設全体の統計
  Map<String, dynamic> _facilityStats = {};

  // 曜日別出勤予定（当月のみ表示）
  Map<String, Map<String, int>> _weeklySchedule = {};
  // 曜日別出勤予定の詳細（元の値ごとのカウント）
  Map<String, Map<String, Map<String, int>>> _weeklyDetails = {};

  // 利用者一覧（個人分析用・当月のみ）
  List<User> _users = [];
  User? _selectedUser;
  Map<String, dynamic>? _userStats;
  List<Attendance> _userHealthHistory = [];  // 過去60回分の健康履歴
  bool _isLoadingUserStats = false;

  // 退所者一覧
  List<Map<String, dynamic>> _departedUsers = [];

  // 年度統計（施設情報用）
  Map<String, dynamic> _yearlyStats = {};
  List<Map<String, dynamic>> _monthlySummary = [];

  // 市区町村別統計
  List<Map<String, dynamic>> _municipalityStats = [];
  int _municipalityTotalUsers = 0;

  // 年齢別分布
  List<Map<String, dynamic>> _ageDistribution = [];
  int _ageTotalUsers = 0;

  /// 当月かどうか
  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

  /// 選択月のフォーマット（YYYY-MM）
  String get _monthString {
    return '${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _attendanceService = AttendanceService(gasUrl: widget.gasUrl);
    _masterService = MasterService(gasUrl: widget.gasUrl);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // バッチAPIで一括取得 + 当月のみ利用者一覧も並列取得
      final futures = <Future>[
        _loadAnalyticsBatch(),
        _loadYearlyStats(),  // 施設情報用の年度統計
        _loadMunicipalityStats(),  // 市区町村別統計
        _loadAgeDistribution(),  // 年齢別分布
      ];

      // 当月の場合のみ利用者一覧を読み込む
      if (_isCurrentMonth) {
        futures.add(_loadUsers());
      }

      await Future.wait(futures);

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

  /// 分析データをバッチ取得（施設統計・退所者・曜日別予定を一括）
  Future<void> _loadAnalyticsBatch() async {
    final month = _isCurrentMonth ? null : _monthString;
    final result = await _attendanceService.getAnalyticsBatch(month: month);
    if (!mounted) return;

    setState(() {
      // 施設統計
      _facilityStats = result['facilityStats'] as Map<String, dynamic>? ?? {};

      // 退所者一覧
      _departedUsers = (result['departedUsers'] as List<dynamic>?)
          ?.map((e) => Map<String, dynamic>.from(e as Map))
          .toList() ?? [];

      // 曜日別予定（当月のみ使用するが、データは常に取得される）
      final weeklyData = result['weeklySchedule'] as Map<String, dynamic>? ?? {};
      _weeklySchedule = (weeklyData['schedule'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, Map<String, int>.from(v as Map))) ?? {};
      _weeklyDetails = (weeklyData['details'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, (v as Map).map((k2, v2) =>
              MapEntry(k2.toString(), Map<String, int>.from(v2 as Map))))) ?? {};
    });
  }

  /// 利用者一覧を読み込む（当月のみ）
  Future<void> _loadUsers() async {
    final users = await _masterService.getActiveUsers();
    if (!mounted) return;
    setState(() {
      _users = users;
    });
  }

  /// 年度統計を読み込む（施設情報用）
  Future<void> _loadYearlyStats() async {
    try {
      // 現在の年度を計算
      final now = DateTime.now();
      final fiscalYear = now.month >= 4 ? now.year : now.year - 1;

      final stats = await _attendanceService.getYearlyStats(fiscalYear: fiscalYear);
      if (!mounted) return;

      setState(() {
        _yearlyStats = stats;
        // monthlySummaryを抽出
        _monthlySummary = (stats['monthlySummary'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ?? [];
      });
    } catch (e) {
      // エラー時はデータをクリア
      if (!mounted) return;
      setState(() {
        _yearlyStats = {};
        _monthlySummary = [];
      });
    }
  }

  /// 市区町村別統計を読み込む
  Future<void> _loadMunicipalityStats() async {
    try {
      final result = await _attendanceService.getMunicipalityStats();
      if (!mounted) return;

      setState(() {
        _municipalityTotalUsers = result['totalUsers'] as int? ?? 0;
        _municipalityStats = (result['municipalities'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ?? [];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _municipalityStats = [];
        _municipalityTotalUsers = 0;
      });
    }
  }

  /// 年齢別分布を読み込む
  Future<void> _loadAgeDistribution() async {
    try {
      final result = await _attendanceService.getAgeDistribution();
      if (!mounted) return;

      setState(() {
        _ageTotalUsers = result['totalUsers'] as int? ?? 0;
        _ageDistribution = (result['ageGroups'] as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ?? [];
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ageDistribution = [];
        _ageTotalUsers = 0;
      });
    }
  }

  /// 月を変更
  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta, 1);
      // 個人分析をクリア
      _selectedUser = null;
      _userStats = null;
      _userHealthHistory = [];
    });
    _loadData();
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
      appBar: AppBar(
        title: const Text('統計・分析'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
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
                        // 月セレクター + 年度統計ボタン
                        _buildMonthSelector(),
                        const SizedBox(height: 8),
                        // 年度統計ボタン
                        _buildYearlyStatsButton(),
                        const SizedBox(height: 16),
                        // 施設全体の統計
                        _buildFacilityStatsSection(),
                        const SizedBox(height: 24),
                        // 市区町村別統計
                        _buildMunicipalityStatsSection(),
                        const SizedBox(height: 24),
                        // 年齢別分布
                        _buildAgeDistributionSection(),
                        const SizedBox(height: 24),
                        // 当月のみ: 曜日別出勤予定
                        if (_isCurrentMonth) ...[
                          _buildWeeklyScheduleSection(),
                          const SizedBox(height: 24),
                        ],
                        // 退所者一覧
                        _buildDepartedUsersSection(),
                        const SizedBox(height: 24),
                        // 当月のみ: 利用者個人分析
                        if (_isCurrentMonth) ...[
                          _buildUserAnalysisSection(),
                          const SizedBox(height: 24),
                        ],
                        // 施設情報（年度月別実利用数）
                        _buildFacilityInfoSection(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
    );
  }

  /// 月セレクター
  Widget _buildMonthSelector() {
    final now = DateTime.now();
    final isCurrentMonth = _isCurrentMonth;

    return Card(
      elevation: 2,
      color: Colors.indigo.shade50,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () => _changeMonth(-1),
              icon: const Icon(Icons.chevron_left),
              color: Colors.indigo,
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedMonth,
                  firstDate: DateTime(2024, 1),
                  lastDate: now,
                  initialDatePickerMode: DatePickerMode.year,
                  locale: const Locale('ja'),
                );
                if (picked != null) {
                  setState(() {
                    _selectedMonth = DateTime(picked.year, picked.month, 1);
                    _selectedUser = null;
                    _userStats = null;
                    _userHealthHistory = [];
                  });
                  _loadData();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.indigo.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_month, color: Colors.indigo.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      '${_selectedMonth.year}年${_selectedMonth.month}月',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.indigo.shade700,
                      ),
                    ),
                    if (isCurrentMonth) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          '当月',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: isCurrentMonth ? null : () => _changeMonth(1),
              icon: const Icon(Icons.chevron_right),
              color: isCurrentMonth ? Colors.grey : Colors.indigo,
            ),
          ],
        ),
      ),
    );
  }

  /// 年度統計ボタン
  Widget _buildYearlyStatsButton() {
    // 現在の年度を計算
    final now = DateTime.now();
    final currentFiscalYear = now.month >= 4 ? now.year : now.year - 1;

    return Center(
      child: ElevatedButton.icon(
        onPressed: () => _showYearlyStatsDialog(currentFiscalYear),
        icon: const Icon(Icons.calendar_view_month),
        label: Text('$currentFiscalYear年度 統計を見る'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
    );
  }

  /// 年度統計ダイアログを表示
  Future<void> _showYearlyStatsDialog(int fiscalYear) async {
    // ローディングダイアログを表示
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final stats = await _attendanceService.getYearlyStats(fiscalYear: fiscalYear);
      if (!mounted) return;
      Navigator.pop(context); // ローディングを閉じる

      // 統計ダイアログを表示
      showDialog(
        context: context,
        builder: (context) => _YearlyStatsDialog(
          stats: stats,
          onYearChange: (newYear) {
            Navigator.pop(context);
            _showYearlyStatsDialog(newYear);
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // ローディングを閉じる
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('年度統計の取得に失敗しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
    final avgUsersPerDay = (_facilityStats['avgUsersPerDay'] as num?)?.toDouble() ?? 0.0;
    final avgUsersChange = (_facilityStats['avgUsersChange'] as num?)?.toDouble() ?? 0.0;

    final monthLabel = _isCurrentMonth ? '当月' : '${_selectedMonth.month}月';

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
                  child: InkWell(
                    onTap: () => _showActiveUsersDialog(monthLabel),
                    borderRadius: BorderRadius.circular(8),
                    child: _buildStatCard(
                      icon: Icons.people,
                      label: '$monthLabel利用者数',
                      value: '$totalUsers名',
                      color: Colors.blue,
                    ),
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
                    label: '$monthLabel稼働日数',
                    value: '$monthlyWorkDays日',
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.check_circle,
                    label: '$monthLabel出勤延べ数',
                    value: '$monthlyAttendance回',
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.groups,
                    label: '1日平均利用人数',
                    value: '${avgUsersPerDay.toStringAsFixed(1)}人',
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildChangeStatCard(
                    avgUsersChange: avgUsersChange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 前月比カード
  Widget _buildChangeStatCard({required double avgUsersChange}) {
    final isPositive = avgUsersChange > 0;
    final isNegative = avgUsersChange < 0;
    final changeColor = isPositive ? Colors.green : (isNegative ? Colors.red : Colors.grey);
    final changeIcon = isPositive ? Icons.trending_up : (isNegative ? Icons.trending_down : Icons.trending_flat);
    final changeText = isPositive
        ? '+${avgUsersChange.toStringAsFixed(1)}人'
        : '${avgUsersChange.toStringAsFixed(1)}人';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: changeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: changeColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(changeIcon, color: changeColor, size: 28),
          const SizedBox(height: 8),
          Text(
            '前月比',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            changeText,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: changeColor,
            ),
          ),
        ],
      ),
    );
  }

  /// 利用者一覧ダイアログを表示
  void _showActiveUsersDialog(String monthLabel) {
    final activeUsersList = _facilityStats['activeUsersList'] as List<dynamic>? ?? [];
    final totalUsers = _facilityStats['totalUsers'] ?? 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.people, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            Text('$monthLabel利用者一覧'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: activeUsersList.isEmpty
              ? const Center(
                  child: Text(
                    '利用者がいません',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: activeUsersList.length,
                  itemBuilder: (context, index) {
                    final userName = activeUsersList[index].toString();
                    final isRetired = userName.contains('（退所）');
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: isRetired
                            ? Colors.grey.shade200
                            : Colors.blue.shade100,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isRetired
                                ? Colors.grey.shade600
                                : Colors.blue.shade700,
                          ),
                        ),
                      ),
                      title: Text(
                        userName,
                        style: TextStyle(
                          color: isRetired ? Colors.grey : null,
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          Text(
            '合計: $totalUsers名',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
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

  /// 市区町村別統計セクション
  Widget _buildMunicipalityStatsSection() {
    // カードの色リスト
    const cardColors = [
      Colors.blue,
      Colors.teal,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.indigo,
      Colors.green,
      Colors.amber,
    ];

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_city, color: Colors.teal.shade700),
                const SizedBox(width: 8),
                Text(
                  '市区町村別利用者数',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '全$_municipalityTotalUsers名',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            if (_municipalityStats.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    '市区町村データがありません',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.0,
                ),
                itemCount: _municipalityStats.length,
                itemBuilder: (context, index) {
                  final stat = _municipalityStats[index];
                  final name = stat['name'] as String? ?? '未設定';
                  final count = stat['count'] as int? ?? 0;
                  final percentage = (stat['percentage'] as num?)?.toDouble() ?? 0.0;
                  final users = (stat['users'] as List<dynamic>?) ?? [];
                  final color = cardColors[index % cardColors.length];

                  return InkWell(
                    onTap: () => _showMunicipalityUsersDialog(name, users),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: color.shade700,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$count名',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: color.shade700,
                            ),
                          ),
                          Text(
                            '${percentage.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 11,
                              color: color.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  /// 市区町村の利用者一覧ダイアログ
  void _showMunicipalityUsersDialog(String municipalityName, List<dynamic> users) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.location_city, color: Colors.teal.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$municipalityName（${users.length}名）',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: users.isEmpty
              ? const Center(
                  child: Text(
                    '利用者がいません',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final userName = users[index].toString();
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.teal.shade100,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.teal.shade700,
                          ),
                        ),
                      ),
                      title: Text(userName),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: Colors.grey.shade400,
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _showUserAttendanceHistoryDialog(userName);
                      },
                    );
                  },
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

  /// 年齢別分布セクション
  Widget _buildAgeDistributionSection() {
    // カードの色リスト（年代ごとにグラデーション）
    const cardColors = [
      Colors.blue,
      Colors.cyan,
      Colors.teal,
      Colors.green,
      Colors.lime,
      Colors.amber,
      Colors.orange,
      Colors.deepOrange,
      Colors.red,
      Colors.pink,
      Colors.purple,
      Colors.grey,
    ];

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cake, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Text(
                  '年齢別分布',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '全$_ageTotalUsers名',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            if (_ageDistribution.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    '年齢データがありません',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.0,
                ),
                itemCount: _ageDistribution.length,
                itemBuilder: (context, index) {
                  final stat = _ageDistribution[index];
                  final name = stat['name'] as String? ?? '未設定';
                  final count = stat['count'] as int? ?? 0;
                  final percentage = (stat['percentage'] as num?)?.toDouble() ?? 0.0;
                  final users = (stat['users'] as List<dynamic>?) ?? [];
                  final color = cardColors[index % cardColors.length];

                  return InkWell(
                    onTap: () => _showAgeGroupUsersDialog(name, users),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: color.shade700,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$count名',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: color.shade700,
                            ),
                          ),
                          Text(
                            '${percentage.toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 11,
                              color: color.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  /// 年齢別の利用者一覧ダイアログ
  void _showAgeGroupUsersDialog(String ageGroup, List<dynamic> users) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.cake, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$ageGroup（${users.length}名）',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: users.isEmpty
              ? const Center(
                  child: Text(
                    '利用者がいません',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final userName = users[index].toString();
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.orange.shade100,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                      title: Text(userName),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: Colors.grey.shade400,
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        _showUserAttendanceHistoryDialog(userName);
                      },
                    );
                  },
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

  /// 利用者の出勤履歴ダイアログ（過去6ヶ月）
  void _showUserAttendanceHistoryDialog(String userName) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _UserAttendanceHistoryDialog(
        userName: userName,
        attendanceService: _attendanceService,
      ),
    );
  }

  /// 曜日別出勤予定セクション
  Widget _buildWeeklyScheduleSection() {
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    const types = ['本施設', '在宅'];
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
            // 施設外 行
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

  /// 退所者セクション
  Widget _buildDepartedUsersSection() {
    final monthLabel = _isCurrentMonth ? '当月' : '${_selectedMonth.month}月';

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
                  '$monthLabel退所者一覧',
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
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    '$monthLabelの退所者はいません',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ...(_departedUsers.take(10).map((user) {
                final name = user['userName'] as String? ?? '';
                final furigana = '';
                final leaveDate = user['leaveDate'] as String? ?? '';
                final leaveReason = user['leaveReason'] as String? ?? '';

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.red.shade100,
                    child: Text(
                      name.isNotEmpty ? name.substring(0, 1) : '?',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                  title: Text(name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(furigana),
                      if (leaveDate.isNotEmpty)
                        Text(
                          '退所日: $leaveDate${leaveReason.isNotEmpty ? " ($leaveReason)" : ""}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                  dense: true,
                  isThreeLine: leaveDate.isNotEmpty,
                );
              })),
            if (_departedUsers.length > 10)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: Text(
                    '他 ${_departedUsers.length - 10}名',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 施設情報セクション（年間月別実利用数）
  Widget _buildFacilityInfoSection() {
    final fiscalYearLabel = _yearlyStats['fiscalYearLabel'] as String? ?? '年度';

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.domain, color: Colors.teal.shade700),
                const SizedBox(width: 8),
                Text(
                  '施設情報',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    fiscalYearLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            // テーブルタイトル
            Row(
              children: [
                Icon(Icons.table_chart, color: Colors.teal.shade600, size: 18),
                const SizedBox(width: 6),
                Text(
                  '施設ごとの延べ人数',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 月別テーブル（横スクロール可能）
            if (_monthlySummary.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('データがありません', style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _buildMonthlyTable(),
              ),
            const SizedBox(height: 16),
            // 平均テーブルタイトル
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.teal.shade600, size: 18),
                const SizedBox(width: 6),
                Text(
                  '施設ごとの利用人数平均',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 平均テーブル（横スクロール可能）
            if (_monthlySummary.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _buildMonthlyAverageTable(),
              ),
            const SizedBox(height: 16),
            // 直接支援員配置と福祉専門員等配置加算要件を横に並べる
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 左側: 直接処遇職員配置
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.people, color: Colors.teal.shade600, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            '直接処遇職員配置',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildDirectSupportStaffTable(),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // 右側: 福祉専門員等配置加算要件
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.verified, color: Colors.indigo.shade600, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            '福祉専門員等配置加算要件',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildWelfareQualificationTable(),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 月別実利用数テーブル
  Widget _buildMonthlyTable() {
    // 月名を取得（4月〜翌3月）
    final months = ['4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月', '1月', '2月', '3月'];

    // 合計を計算
    int totalFacilityHome = 0;
    int totalExternal = 0;
    for (final data in _monthlySummary) {
      totalFacilityHome += (data['facilityHome'] as num?)?.toInt() ?? 0;
      totalExternal += (data['external'] as num?)?.toInt() ?? 0;
    }

    return Table(
      defaultColumnWidth: const FixedColumnWidth(52),
      border: TableBorder.all(color: Colors.grey.shade300),
      children: [
        // ヘッダー行（月）
        TableRow(
          decoration: BoxDecoration(color: Colors.teal.shade50),
          children: [
            _buildTableHeaderCell(''),
            ...months.map((m) => _buildTableHeaderCell(m)),
            _buildTableHeaderCell('合計'),
          ],
        ),
        // 本施設・在宅 行
        TableRow(
          children: [
            _buildTableLabelCell('本施設\n在宅', Colors.blue),
            ..._monthlySummary.map((data) => _buildTableDataCell(
              (data['facilityHome'] as num?)?.toInt() ?? 0,
              Colors.blue,
            )),
            _buildTableTotalCell(totalFacilityHome, Colors.blue),
          ],
        ),
        // 施設外 行
        TableRow(
          children: [
            _buildTableLabelCell('施設外', Colors.orange),
            ..._monthlySummary.map((data) => _buildTableDataCell(
              (data['external'] as num?)?.toInt() ?? 0,
              Colors.orange,
            )),
            _buildTableTotalCell(totalExternal, Colors.orange),
          ],
        ),
      ],
    );
  }

  /// 月別利用人数平均テーブル
  Widget _buildMonthlyAverageTable() {
    // 月名を取得（4月〜翌3月）
    final months = ['4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月', '1月', '2月', '3月'];

    // 年間平均を計算（総延べ人数 ÷ 総稼働日数）
    double totalFacilityHome = 0;
    double totalExternal = 0;
    double totalWorkDays = 0;
    for (final data in _monthlySummary) {
      totalFacilityHome += (data['facilityHome'] as num?)?.toDouble() ?? 0.0;
      totalExternal += (data['external'] as num?)?.toDouble() ?? 0.0;
      totalWorkDays += (data['workDays'] as num?)?.toDouble() ?? 0.0;
    }
    final yearlyAvgFacilityHome = totalWorkDays > 0 ? totalFacilityHome / totalWorkDays : 0.0;
    final yearlyAvgExternal = totalWorkDays > 0 ? totalExternal / totalWorkDays : 0.0;

    return Table(
      defaultColumnWidth: const FixedColumnWidth(52),
      border: TableBorder.all(color: Colors.grey.shade300),
      children: [
        // ヘッダー行（月）
        TableRow(
          decoration: BoxDecoration(color: Colors.teal.shade50),
          children: [
            _buildTableHeaderCell(''),
            ...months.map((m) => _buildTableHeaderCell(m)),
            _buildTableHeaderCell('年間'),
          ],
        ),
        // 本施設・在宅 平均行
        TableRow(
          children: [
            _buildTableLabelCell('本施設\n在宅', Colors.blue),
            ..._monthlySummary.map((data) {
              final facilityHome = (data['facilityHome'] as num?)?.toDouble() ?? 0.0;
              final workDays = (data['workDays'] as num?)?.toDouble() ?? 0.0;
              final average = workDays > 0 ? facilityHome / workDays : 0.0;
              return _buildTableAverageCell(average, Colors.blue);
            }),
            _buildTableAverageTotalCell(yearlyAvgFacilityHome, Colors.blue),
          ],
        ),
        // 施設外 平均行
        TableRow(
          children: [
            _buildTableLabelCell('施設外', Colors.orange),
            ..._monthlySummary.map((data) {
              final external = (data['external'] as num?)?.toDouble() ?? 0.0;
              final workDays = (data['workDays'] as num?)?.toDouble() ?? 0.0;
              final average = workDays > 0 ? external / workDays : 0.0;
              return _buildTableAverageCell(average, Colors.orange);
            }),
            _buildTableAverageTotalCell(yearlyAvgExternal, Colors.orange),
          ],
        ),
      ],
    );
  }

  /// 直接支援員配置テーブル（雇用形態別）
  Widget _buildDirectSupportStaffTable() {
    final directSupportStaff = _yearlyStats['directSupportStaff'] as Map<String, dynamic>?;
    final byEmploymentType = directSupportStaff?['byEmploymentType'] as Map<String, dynamic>?;

    // 雇用形態別データを取得
    final fullTime = byEmploymentType?['fullTime'] as Map<String, dynamic>?;
    final partTimeLess2 = byEmploymentType?['partTimeLess2'] as Map<String, dynamic>?;
    final partTimeMore3 = byEmploymentType?['partTimeMore3'] as Map<String, dynamic>?;

    // 各雇用形態の人数を取得
    final fullTimeFacility = (fullTime?['facilityHome'] as num?)?.toInt() ?? 0;
    final fullTimeExternal = (fullTime?['external'] as num?)?.toInt() ?? 0;
    final partTimeLess2Facility = (partTimeLess2?['facilityHome'] as num?)?.toInt() ?? 0;
    final partTimeLess2External = (partTimeLess2?['external'] as num?)?.toInt() ?? 0;
    final partTimeMore3Facility = (partTimeMore3?['facilityHome'] as num?)?.toInt() ?? 0;
    final partTimeMore3External = (partTimeMore3?['external'] as num?)?.toInt() ?? 0;

    // 合計
    final totalFacility = fullTimeFacility + partTimeLess2Facility + partTimeMore3Facility;
    final totalExternal = fullTimeExternal + partTimeLess2External + partTimeMore3External;

    return Table(
      defaultColumnWidth: const FixedColumnWidth(80),
      border: TableBorder.all(color: Colors.grey.shade300),
      children: [
        // ヘッダー行
        TableRow(
          decoration: BoxDecoration(color: Colors.teal.shade50),
          children: [
            _buildTableHeaderCell('雇用形態'),
            _buildTableHeaderCell('本施設\n在宅'),
            _buildTableHeaderCell('施設外'),
          ],
        ),
        // 常勤職員
        TableRow(
          children: [
            _buildTableLabelCell('常勤職員', Colors.blue),
            _buildTableDataCell(fullTimeFacility, Colors.blue),
            _buildTableDataCell(fullTimeExternal, Colors.orange),
          ],
        ),
        // 非常勤職員（2日以下）
        TableRow(
          children: [
            _buildTableLabelCell('非常勤\n(2日以下)', Colors.green),
            _buildTableDataCell(partTimeLess2Facility, Colors.blue),
            _buildTableDataCell(partTimeLess2External, Colors.orange),
          ],
        ),
        // 非常勤職員（3日以上）
        TableRow(
          children: [
            _buildTableLabelCell('非常勤\n(3日以上)', Colors.purple),
            _buildTableDataCell(partTimeMore3Facility, Colors.blue),
            _buildTableDataCell(partTimeMore3External, Colors.orange),
          ],
        ),
        // 合計行
        TableRow(
          decoration: BoxDecoration(color: Colors.grey.shade100),
          children: [
            _buildTableLabelCell('合計', Colors.grey.shade700),
            _buildTableTotalCell(totalFacility, Colors.blue),
            _buildTableTotalCell(totalExternal, Colors.orange),
          ],
        ),
      ],
    );
  }

  /// 福祉専門員等配置加算要件テーブル
  Widget _buildWelfareQualificationTable() {
    final welfareQualification = _yearlyStats['welfareQualification'] as Map<String, dynamic>?;
    final total = (welfareQualification?['total'] as num?)?.toInt() ?? 0;
    final withQualification = (welfareQualification?['withQualification'] as num?)?.toInt() ?? 0;
    final rate = (welfareQualification?['rate'] as num?)?.toInt() ?? 0;

    // 加算判定
    String? bonusLevel;
    Color bonusColor;
    if (rate >= 35) {
      bonusLevel = '福祉専門職等配置加算（Ⅰ）';
      bonusColor = Colors.green.shade700;
    } else if (rate >= 25) {
      bonusLevel = '福祉専門職等配置加算（Ⅱ）';
      bonusColor = Colors.orange.shade700;
    } else {
      bonusLevel = null;
      bonusColor = Colors.grey.shade700;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // テーブル
        Table(
          defaultColumnWidth: const FixedColumnWidth(80),
          border: TableBorder.all(color: Colors.grey.shade300),
          children: [
            // ヘッダー行
            TableRow(
              decoration: BoxDecoration(color: Colors.indigo.shade50),
              children: [
                _buildTableHeaderCellIndigo('項目'),
                _buildTableHeaderCellIndigo('人数'),
              ],
            ),
            // 常勤直接処遇職員数
            TableRow(
              children: [
                _buildTableLabelCell('常勤直接\n処遇職員', Colors.indigo),
                _buildTableDataCell(total, Colors.indigo),
              ],
            ),
            // 福祉資格保有者数
            TableRow(
              children: [
                _buildTableLabelCell('福祉資格\n保有者', Colors.green),
                _buildTableDataCell(withQualification, Colors.green),
              ],
            ),
            // 保有率
            TableRow(
              decoration: BoxDecoration(color: bonusLevel != null ? Colors.green.shade50 : Colors.grey.shade100),
              children: [
                _buildTableLabelCell('保有率', bonusLevel != null ? Colors.green.shade700 : Colors.grey.shade700),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  alignment: Alignment.center,
                  child: Text(
                    '$rate%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: bonusLevel != null ? Colors.green.shade700 : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        // 加算判定表示
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 12, top: 8),
            child: bonusLevel != null
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: bonusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: bonusColor, width: 1.5),
                    ),
                    child: Text(
                      bonusLevel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: bonusColor,
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade400, width: 1.5),
                        ),
                        child: Text(
                          '福祉専門職等配置加算に該当せず',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '※福祉専門職等配置加算（Ⅲ）に該当するかもしれません。以下を確認してください',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '・直接処遇職員の常勤従業員が75%以上または常勤従業員のうち3年以上従事している従業員の割合が30%以上',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeaderCellIndigo(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.indigo.shade700,
        ),
      ),
    );
  }

  Widget _buildTableHeaderCell(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.teal.shade700,
        ),
      ),
    );
  }

  Widget _buildTableLabelCell(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      alignment: Alignment.center,
      color: color.withValues(alpha: 0.1),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildTableDataCell(int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      alignment: Alignment.center,
      child: Text(
        value > 0 ? '$value' : '-',
        style: TextStyle(
          fontSize: 12,
          fontWeight: value > 0 ? FontWeight.bold : FontWeight.normal,
          color: value > 0 ? color : Colors.grey.shade400,
        ),
      ),
    );
  }

  Widget _buildTableAverageCell(double value, Color color) {
    final hasValue = value > 0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      alignment: Alignment.center,
      child: Text(
        hasValue ? value.toStringAsFixed(1) : '-',
        style: TextStyle(
          fontSize: 12,
          fontWeight: hasValue ? FontWeight.bold : FontWeight.normal,
          color: hasValue ? color : Colors.grey.shade400,
        ),
      ),
    );
  }

  Widget _buildTableTotalCell(int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      alignment: Alignment.center,
      color: color.withValues(alpha: 0.15),
      child: Text(
        value > 0 ? '$value' : '-',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildTableAverageTotalCell(double value, Color color) {
    final hasValue = value > 0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      alignment: Alignment.center,
      color: color.withValues(alpha: 0.15),
      child: Text(
        hasValue ? value.toStringAsFixed(1) : '-',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
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
          _buildHealthChartsGrid(),
        ],
      ],
    );
  }

  /// 健康グラフの2x2グリッド
  Widget _buildHealthChartsGrid() {
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
    final sortedHistory = _userHealthHistory.reversed.toList();
    final dataPoints = extractHealthData(sortedHistory, type);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullScreenHealthChart(
          dataPoints: dataPoints,
          type: type,
          userName: _selectedUser?.name ?? '',
        ),
      ),
    );
  }
}

/// 全画面健康グラフ
class _FullScreenHealthChart extends StatelessWidget {
  final List<HealthDataPoint> dataPoints;
  final HealthMetricType type;
  final String userName;

  const _FullScreenHealthChart({
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
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: validPoints.isEmpty
                  ? const Center(child: Text('データがありません'))
                  : _buildChart(validPoints),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            flex: 2,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: dataPoints.length,
              itemBuilder: (context, index) {
                final point = dataPoints[dataPoints.length - 1 - index];
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
          Expanded(
            child: Text(
              point.label ?? '--',
              style: TextStyle(
                fontSize: 14,
                color: hasValue ? Colors.black87 : Colors.grey.shade400,
              ),
            ),
          ),
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

/// 年度統計ダイアログ
class _YearlyStatsDialog extends StatelessWidget {
  final Map<String, dynamic> stats;
  final Function(int) onYearChange;

  const _YearlyStatsDialog({
    required this.stats,
    required this.onYearChange,
  });

  @override
  Widget build(BuildContext context) {
    final fiscalYear = (stats['fiscalYear'] as num?)?.toInt() ?? DateTime.now().year;
    final fiscalYearLabel = stats['fiscalYearLabel'] as String? ?? '$fiscalYear年度';
    final yearlyAttendance = (stats['yearlyAttendance'] as num?)?.toInt() ?? 0;
    final yearlyWorkDays = (stats['yearlyWorkDays'] as num?)?.toInt() ?? 0;
    final attendanceRate = (stats['attendanceRate'] as num?)?.toDouble() ?? 0.0;
    final yearlyDeparted = (stats['yearlyDeparted'] as num?)?.toInt() ?? 0;
    final monthlySummary = (stats['monthlySummary'] as List<dynamic>?)
        ?.map((e) => e as Map<String, dynamic>)
        .toList() ?? [];

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ヘッダー
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => onYearChange(fiscalYear - 1),
                    icon: const Icon(Icons.chevron_left, color: Colors.white),
                  ),
                  Expanded(
                    child: Text(
                      fiscalYearLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      final now = DateTime.now();
                      final currentFY = now.month >= 4 ? now.year : now.year - 1;
                      if (fiscalYear < currentFY) {
                        onYearChange(fiscalYear + 1);
                      }
                    },
                    icon: Icon(
                      Icons.chevron_right,
                      color: fiscalYear < (DateTime.now().month >= 4 ? DateTime.now().year : DateTime.now().year - 1)
                          ? Colors.white
                          : Colors.white38,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            // 統計サマリー
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.check_circle,
                          label: '年度出勤延べ数',
                          value: '$yearlyAttendance回',
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.pie_chart,
                          label: '年度出勤率',
                          value: '${(attendanceRate * 100).toStringAsFixed(1)}%',
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
                          icon: Icons.calendar_today,
                          label: '年度稼働日数',
                          value: '$yearlyWorkDays日',
                          color: Colors.orange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.person_off,
                          label: '年度退所者数',
                          value: '$yearlyDeparted名',
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 月別内訳
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.list_alt, color: Colors.grey.shade700, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '月別内訳',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            // 月別リスト
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: monthlySummary.length,
                itemBuilder: (context, index) {
                  final item = monthlySummary[index];
                  final month = item['month'] as String? ?? '';
                  final attendance = (item['attendance'] as num?)?.toInt() ?? 0;
                  final workDays = (item['workDays'] as num?)?.toInt() ?? 0;

                  // 月名を日本語に変換
                  final parts = month.split('-');
                  final monthLabel = parts.length == 2
                      ? '${parts[0]}年${int.parse(parts[1])}月'
                      : month;

                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 100,
                          child: Text(
                            monthLabel,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildMiniStat('出勤', '$attendance回', Colors.green),
                              _buildMiniStat('稼働', '$workDays日', Colors.orange),
                              _buildMiniStat('平均', workDays > 0 ? '${(attendance / workDays).toStringAsFixed(1)}人' : '-', Colors.blue),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
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
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

/// 利用者出勤履歴ダイアログ（過去6ヶ月）
class _UserAttendanceHistoryDialog extends StatefulWidget {
  final String userName;
  final AttendanceService attendanceService;

  const _UserAttendanceHistoryDialog({
    required this.userName,
    required this.attendanceService,
  });

  @override
  State<_UserAttendanceHistoryDialog> createState() => _UserAttendanceHistoryDialogState();
}

class _UserAttendanceHistoryDialogState extends State<_UserAttendanceHistoryDialog> {
  bool _isLoading = true;
  String? _errorMessage;
  int _totalDays = 0;
  int _totalRemoteDays = 0;
  Map<String, List<Map<String, dynamic>>> _monthlyData = {};
  Map<String, List<Map<String, dynamic>>> _remoteMonthlyData = {};

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final result = await widget.attendanceService.getUserAttendanceHistory(widget.userName);
      if (!mounted) return;

      setState(() {
        _totalDays = result['totalDays'] as int? ?? 0;
        _totalRemoteDays = result['totalRemoteDays'] as int? ?? 0;
        _monthlyData = _parseMonthlyData(result['monthlyData']);
        _remoteMonthlyData = _parseMonthlyData(result['remoteMonthlyData']);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '履歴の取得に失敗しました';
        _isLoading = false;
      });
    }
  }

  Map<String, List<Map<String, dynamic>>> _parseMonthlyData(dynamic data) {
    if (data == null) return {};
    final Map<String, dynamic> rawData = Map<String, dynamic>.from(data as Map);
    return rawData.map((key, value) {
      final List<dynamic> list = value as List<dynamic>;
      return MapEntry(
        key,
        list.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(8, 16, 16, 0),
      title: Row(
        children: [
          // 戻るボタン
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            color: Colors.grey.shade600,
            tooltip: '戻る',
          ),
          Icon(Icons.calendar_month, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.userName,
                  style: const TextStyle(fontSize: 18),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 450,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  )
                : _buildHistoryContent(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('閉じる'),
        ),
      ],
    );
  }

  Widget _buildHistoryContent() {
    // 月のキーをソート（新しい順）
    final allMonths = <String>{
      ..._monthlyData.keys,
      ..._remoteMonthlyData.keys,
    }.toList()
      ..sort((a, b) => b.compareTo(a));

    if (allMonths.isEmpty) {
      return const Center(
        child: Text(
          '過去6ヶ月の出勤記録がありません',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: allMonths.length,
      itemBuilder: (context, index) {
        final monthKey = allMonths[index];
        final attendanceList = _monthlyData[monthKey] ?? [];
        final remoteList = _remoteMonthlyData[monthKey] ?? [];

        // 月表示用のフォーマット
        final year = monthKey.substring(0, 4);
        final month = monthKey.substring(5, 7);
        final monthLabel = '$year年$month月';

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ExpansionTile(
            initiallyExpanded: index == 0,
            title: Row(
              children: [
                Text(
                  monthLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (attendanceList.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '出勤${attendanceList.length}日',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                if (remoteList.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '在宅${remoteList.length}日',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            children: [
              // 2カラムレイアウト: 左に出勤、右に在宅
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 左カラム: 出勤
                    Expanded(
                      child: _buildDateColumn('出勤', attendanceList, Colors.blue),
                    ),
                    const SizedBox(width: 16),
                    // 右カラム: 在宅
                    Expanded(
                      child: _buildDateColumn('在宅', remoteList, Colors.green),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDateColumn(String label, List<Map<String, dynamic>> dates, MaterialColor color) {
    // 日付を昇順にソート（1日〜31日）
    final sortedDates = List<Map<String, dynamic>>.from(dates);
    sortedDates.sort((a, b) {
      final dateA = a['date'] as String? ?? '';
      final dateB = b['date'] as String? ?? '';
      return dateA.compareTo(dateB);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ヘッダー: ラベルと日数
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color.shade700,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${dates.length}日',
              style: TextStyle(
                fontSize: 12,
                color: color.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // 日付一覧（左寄せ）
        if (sortedDates.isEmpty)
          Text(
            'なし',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
          )
        else
          Align(
            alignment: Alignment.topLeft,
            child: Wrap(
              alignment: WrapAlignment.start,
              spacing: 4,
              runSpacing: 4,
              children: sortedDates.map((item) {
                final dateStr = item['date'] as String? ?? '';
                final status = item['status'] as String? ?? '';
                // 日付部分のみ表示（M/D形式：1/12のように）
                String displayDay = dateStr;
                if (dateStr.length >= 10) {
                  final month = int.tryParse(dateStr.substring(5, 7)) ?? 0;
                  final day = int.tryParse(dateStr.substring(8, 10)) ?? 0;
                  displayDay = '$month/$day';
                }

                // ステータスに応じた色
                MaterialColor statusColor = color;
                if (status == '遅刻') {
                  statusColor = Colors.orange;
                } else if (status == '早退') {
                  statusColor = Colors.purple;
                } else if (status == '施設外') {
                  statusColor = Colors.teal;
                }

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    status != '出勤' && status != '在宅' ? '$displayDay($status)' : displayDay,
                    style: TextStyle(
                      fontSize: 11,
                      color: statusColor.shade700,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
