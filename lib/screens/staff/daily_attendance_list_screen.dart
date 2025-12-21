import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/attendance.dart';
import '../../services/attendance_service.dart';
import '../../services/auth_service.dart';
import '../../config/constants.dart';
import '../common/menu_selection_screen.dart';
import 'user_list_screen.dart';

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

class _DailyAttendanceListScreenState extends State<DailyAttendanceListScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  final AuthService _authService = AuthService();
  List<Attendance> _attendances = [];
  bool _isLoading = true;
  String? _errorMessage;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadAttendances();
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
      _loadAttendances();
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
            onPressed: _loadAttendances,
            tooltip: '再読み込み',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: 'ログアウト',
          ),
        ],
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
                    : _buildAttendanceList(),
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

  /// 勤怠カード
  Widget _buildAttendanceCard(Attendance attendance) {
    final hasComment = attendance.checkinComment != null || attendance.checkoutComment != null;
    final hasNotCheckedOut = attendance.checkinTime != null && attendance.checkoutTime == null;

    // 背景色の優先順位：未退勤 > コメント
    Color? cardColor;
    if (hasNotCheckedOut) {
      cardColor = Colors.yellow.shade50;
    } else if (hasComment) {
      cardColor = Colors.amber.shade50;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      color: cardColor,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(attendance.attendanceStatus),
          child: Text(
            attendance.userName.substring(0, 1),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Text(
              attendance.userName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (hasNotCheckedOut) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.yellow.shade700,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '未退勤',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            if (hasComment) ...[
              const SizedBox(width: 8),
              const Icon(
                Icons.comment,
                size: 18,
                color: Colors.orange,
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            _buildAttendanceStatusText(attendance),
            if (attendance.morningTask != null || attendance.afternoonTask != null)
              _buildTaskText(attendance),
            if (hasComment)
              _buildCommentAlert(attendance),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // TODO: 勤怠編集画面へ遷移
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('勤怠編集機能は次のフェーズで実装予定')),
          );
        },
      ),
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

  /// 午前・午後の業務を1行で表示するテキスト
  Widget _buildTaskText(Attendance attendance) {
    final morningTask = attendance.morningTask;
    final afternoonTask = attendance.afternoonTask;

    // 両方ある場合
    if (morningTask != null && afternoonTask != null) {
      return Text('業務: 午前 $morningTask / 午後 $afternoonTask');
    }
    // 午前のみ
    else if (morningTask != null) {
      return Text('業務: 午前 $morningTask');
    }
    // 午後のみ
    else if (afternoonTask != null) {
      return Text('業務: 午後 $afternoonTask');
    }

    return const SizedBox.shrink();
  }

  /// コメントアラートを表示
  Widget _buildCommentAlert(Attendance attendance) {
    final checkinComment = attendance.checkinComment;
    final checkoutComment = attendance.checkoutComment;

    String commentText = '';

    // 両方ある場合
    if (checkinComment != null && checkoutComment != null) {
      commentText = '出勤時「$checkinComment」/ 退勤時「$checkoutComment」';
    }
    // 出勤時のみ
    else if (checkinComment != null) {
      commentText = '出勤時「$checkinComment」';
    }
    // 退勤時のみ
    else if (checkoutComment != null) {
      commentText = '退勤時「$checkoutComment」';
    }

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.orange.shade100,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.orange.shade300, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber,
            size: 18,
            color: Colors.orange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'コメント: $commentText',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
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
