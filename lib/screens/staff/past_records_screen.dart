import 'package:flutter/material.dart';
import '../../models/attendance.dart';
import '../../models/user.dart';
import '../../services/attendance_service.dart';
import '../../services/master_service.dart';
import '../../widgets/searchable_dropdown.dart';
import '../../theme/app_theme_v2.dart';
import 'user_detail_screen.dart';

/// 検索モード
enum SearchMode {
  byUser,  // 利用者別
  byDate,  // 日付別
}

/// 過去の実績記録画面（支援者用）
class PastRecordsScreen extends StatefulWidget {
  final String staffName;

  const PastRecordsScreen({
    super.key,
    required this.staffName,
  });

  @override
  State<PastRecordsScreen> createState() => _PastRecordsScreenState();
}

class _PastRecordsScreenState extends State<PastRecordsScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  final MasterService _masterService = MasterService();

  // 検索モード
  SearchMode _searchMode = SearchMode.byUser;

  // 利用者別検索用
  List<User> _users = [];
  String? _selectedUserName;

  // 日付別検索用
  DateTime _selectedDate = DateTime.now();

  // 共通
  List<Attendance> _records = [];
  bool _isLoadingUsers = true;
  bool _isLoadingRecords = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  /// 利用者一覧を読み込む（退所済み含む）
  Future<void> _loadUsers() async {
    try {
      setState(() {
        _isLoadingUsers = true;
        _errorMessage = null;
      });

      // 過去の実績記録は退所済みも含めて全利用者を表示
      final users = await _masterService.getAllUsers();

      setState(() {
        _users = users;
        _isLoadingUsers = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '利用者の読み込みに失敗しました\n$e';
        _isLoadingUsers = false;
      });
    }
  }

  /// 選択した利用者の過去記録を読み込む
  Future<void> _loadRecordsByUser() async {
    if (_selectedUserName == null) return;

    try {
      setState(() {
        _isLoadingRecords = true;
        _errorMessage = null;
      });

      final records = await _attendanceService.getUserHistory(_selectedUserName!);

      setState(() {
        _records = records;
        _isLoadingRecords = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '記録の読み込みに失敗しました\n$e';
        _isLoadingRecords = false;
      });
    }
  }

  /// 選択した日付の全員の記録を読み込む
  Future<void> _loadRecordsByDate() async {
    try {
      setState(() {
        _isLoadingRecords = true;
        _errorMessage = null;
      });

      final dateStr = '${_selectedDate.year}/${_selectedDate.month}/${_selectedDate.day}';
      final records = await _attendanceService.getDailyAttendance(dateStr);

      setState(() {
        _records = records;
        _isLoadingRecords = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '記録の読み込みに失敗しました\n$e';
        _isLoadingRecords = false;
      });
    }
  }

  /// 日付選択ダイアログを表示
  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('ja'),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadRecordsByDate();
    }
  }

  /// 曜日を取得
  String _getWeekdayName(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final parts = dateStr.split('/');
      if (parts.length != 3) return '';
      final date = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
      return weekdays[date.weekday - 1];
    } catch (e) {
      return '';
    }
  }

  /// 日付をフォーマット
  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final parts = dateStr.split('/');
      if (parts.length != 3) return dateStr;
      return '${parts[1]}/${parts[2]}';
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeV2.backgroundGrey,
      appBar: AppBar(
        title: const Text('過去の実績記録'),
        backgroundColor: AppThemeV2.accentOrange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 検索モード切り替え
          _buildSearchModeToggle(),
          // 利用者選択 or 日付選択
          _searchMode == SearchMode.byUser
              ? _buildUserSelector()
              : _buildDateSelector(),
          // 記録一覧
          Expanded(
            child: _buildRecordsList(),
          ),
        ],
      ),
    );
  }

  /// 検索モード切り替えトグル
  Widget _buildSearchModeToggle() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: AppThemeV2.accentOrange.withValues(alpha: 0.1),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_searchMode != SearchMode.byUser) {
                  setState(() {
                    _searchMode = SearchMode.byUser;
                    _records = [];
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _searchMode == SearchMode.byUser
                      ? AppThemeV2.accentOrange
                      : Colors.white,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(8),
                  ),
                  border: Border.all(color: AppThemeV2.accentOrange),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_search,
                      size: 20,
                      color: _searchMode == SearchMode.byUser
                          ? Colors.white
                          : AppThemeV2.accentOrange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '利用者別',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _searchMode == SearchMode.byUser
                            ? Colors.white
                            : AppThemeV2.accentOrange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_searchMode != SearchMode.byDate) {
                  setState(() {
                    _searchMode = SearchMode.byDate;
                    _records = [];
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _searchMode == SearchMode.byDate
                      ? AppThemeV2.accentOrange
                      : Colors.white,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(8),
                  ),
                  border: Border.all(color: AppThemeV2.accentOrange),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_month,
                      size: 20,
                      color: _searchMode == SearchMode.byDate
                          ? Colors.white
                          : AppThemeV2.accentOrange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '日付別',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _searchMode == SearchMode.byDate
                            ? Colors.white
                            : AppThemeV2.accentOrange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 利用者選択プルダウン
  Widget _buildUserSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '利用者を選択',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          _isLoadingUsers
              ? const Center(child: CircularProgressIndicator())
              : SearchableDropdown<User>(
                  value: _users.where((u) => u.name == _selectedUserName).firstOrNull,
                  items: _users,
                  itemLabel: (user) => user.status != '契約中'
                      ? '${user.name}（${user.status}）'
                      : user.name,
                  onChanged: (user) {
                    setState(() {
                      _selectedUserName = user?.name;
                    });
                    _loadRecordsByUser();
                  },
                  hint: '名前を入力して検索...',
                ),
        ],
      ),
    );
  }

  /// 日付選択UI
  Widget _buildDateSelector() {
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    final weekday = weekdays[_selectedDate.weekday - 1];
    final dateFormatted = '${_selectedDate.year}/${_selectedDate.month}/${_selectedDate.day} ($weekday)';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '日付を選択',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _selectDate,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: AppThemeV2.accentOrange.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(8),
                color: AppThemeV2.accentOrange.withValues(alpha: 0.1),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: AppThemeV2.accentOrange),
                  const SizedBox(width: 12),
                  Text(
                    dateFormatted,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppThemeV2.accentOrange,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_drop_down, color: AppThemeV2.accentOrange),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 検索ボタン
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loadRecordsByDate,
              icon: const Icon(Icons.search),
              label: const Text('この日の記録を検索'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppThemeV2.accentOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 記録一覧
  Widget _buildRecordsList() {
    // 利用者別モードで未選択の場合
    if (_searchMode == SearchMode.byUser && _selectedUserName == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '利用者を選択してください',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    // 日付別モードで未検索の場合
    if (_searchMode == SearchMode.byDate && _records.isEmpty && !_isLoadingRecords && _errorMessage == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_month, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '日付を選択して検索してください',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    if (_isLoadingRecords) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade700),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _searchMode == SearchMode.byUser
                  ? _loadRecordsByUser
                  : _loadRecordsByDate,
              child: const Text('再試行'),
            ),
          ],
        ),
      );
    }

    if (_records.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '記録がありません',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _searchMode == SearchMode.byUser
          ? _loadRecordsByUser
          : _loadRecordsByDate,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _records.length,
        itemBuilder: (context, index) {
          final record = _records[index];
          return _buildRecordCard(record);
        },
      ),
    );
  }

  /// 記録カード
  Widget _buildRecordCard(Attendance record) {
    final weekday = _getWeekdayName(record.date);
    final dateFormatted = _formatDate(record.date);
    final hasCheckin = record.checkinTime != null;
    final hasCheckout = record.checkoutTime != null;
    final hasSupportRecord = record.hasSupportRecord;

    // 出欠状態の色
    Color statusColor;
    String statusText;
    switch (record.attendanceStatus) {
      case '出勤':
        statusColor = Colors.green;
        statusText = '出勤';
        break;
      case '欠勤':
        statusColor = Colors.red;
        statusText = '欠勤';
        break;
      case '遅刻':
        statusColor = AppThemeV2.accentOrange;
        statusText = '遅刻';
        break;
      case '早退':
        statusColor = Colors.amber;
        statusText = '早退';
        break;
      default:
        statusColor = Colors.grey;
        statusText = record.attendanceStatus ?? '未登録';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () async {
          // 詳細画面へ遷移
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserDetailScreen(
                date: record.date,
                userName: record.userName,
                staffName: widget.staffName,
              ),
            ),
          );
          // 画面から戻ってきたらデータを再読み込み
          if (result == true) {
            if (_searchMode == SearchMode.byUser) {
              _loadRecordsByUser();
            } else {
              _loadRecordsByDate();
            }
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 日付行または利用者名行
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _searchMode == SearchMode.byDate
                          ? Colors.green.shade100
                          : Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_searchMode == SearchMode.byDate) ...[
                          Icon(
                            Icons.person,
                            size: 16,
                            color: Colors.green.shade900,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          _searchMode == SearchMode.byDate
                              ? record.userName ?? '---'
                              : '$dateFormatted ($weekday)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _searchMode == SearchMode.byDate
                                ? Colors.green.shade900
                                : Colors.blue.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 12),
              // 勤怠情報
              Row(
                children: [
                  _buildInfoChip(
                    icon: Icons.login,
                    label: '出勤',
                    value: record.checkinTime ?? '--:--',
                    color: hasCheckin ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 16),
                  _buildInfoChip(
                    icon: Icons.logout,
                    label: '退勤',
                    value: record.checkoutTime ?? '--:--',
                    color: hasCheckout ? Colors.blue : Colors.grey,
                  ),
                  const SizedBox(width: 16),
                  _buildInfoChip(
                    icon: Icons.schedule,
                    label: '実働',
                    value: record.actualWorkMinutes != null
                        ? '${(record.actualWorkMinutes! / 60).floor()}h${record.actualWorkMinutes! % 60}m'
                        : '--',
                    color: Colors.purple,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 支援記録状態
              Row(
                children: [
                  Icon(
                    hasSupportRecord ? Icons.check_circle : Icons.warning,
                    size: 16,
                    color: hasSupportRecord ? Colors.green : AppThemeV2.accentOrange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    hasSupportRecord ? '支援記録あり' : '支援記録未登録',
                    style: TextStyle(
                      fontSize: 12,
                      color: hasSupportRecord ? Colors.green : AppThemeV2.accentOrange,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 情報チップ
  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
