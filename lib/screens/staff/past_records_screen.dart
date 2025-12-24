import 'package:flutter/material.dart';
import '../../models/attendance.dart';
import '../../models/user.dart';
import '../../services/attendance_service.dart';
import '../../services/master_service.dart';
import 'user_detail_screen.dart';

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

  List<User> _users = [];
  String? _selectedUserName;
  List<Attendance> _records = [];
  bool _isLoadingUsers = true;
  bool _isLoadingRecords = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  /// 利用者一覧を読み込む
  Future<void> _loadUsers() async {
    try {
      setState(() {
        _isLoadingUsers = true;
        _errorMessage = null;
      });

      final users = await _masterService.getActiveUsers();

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
  Future<void> _loadRecords() async {
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
      appBar: AppBar(
        title: const Text('過去の実績記録'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // 利用者選択プルダウン
          _buildUserSelector(),
          // 記録一覧
          Expanded(
            child: _buildRecordsList(),
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
              : DropdownButtonFormField<String>(
                  value: _selectedUserName,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  hint: const Text('利用者を選択してください'),
                  items: _users.map((user) {
                    return DropdownMenuItem<String>(
                      value: user.name,
                      child: Text(user.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedUserName = value;
                    });
                    _loadRecords();
                  },
                ),
        ],
      ),
    );
  }

  /// 記録一覧
  Widget _buildRecordsList() {
    if (_selectedUserName == null) {
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
              onPressed: _loadRecords,
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
      onRefresh: _loadRecords,
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
        statusColor = Colors.orange;
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
              ),
            ),
          );
          // 画面から戻ってきたらデータを再読み込み
          if (result == true) {
            _loadRecords();
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 日付行
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$dateFormatted ($weekday)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
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
                    color: hasSupportRecord ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    hasSupportRecord ? '支援記録あり' : '支援記録未登録',
                    style: TextStyle(
                      fontSize: 12,
                      color: hasSupportRecord ? Colors.green : Colors.orange,
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
