import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/attendance.dart';
import '../../models/dropdown_options.dart';
import '../../services/attendance_service.dart';
import '../../services/master_service.dart';
import '../../services/master_auth_service.dart';
import '../../config/constants.dart';
import '../../utils/time_utils.dart';

/// 出勤入力画面（利用者用）
class CheckinScreen extends StatefulWidget {
  final String userName;

  const CheckinScreen({
    super.key,
    required this.userName,
  });

  @override
  State<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends State<CheckinScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  final MasterService _masterService = MasterService();

  DropdownOptions? _dropdownOptions;
  bool _isLoading = true;
  bool _isSubmitting = false;

  // 入力フォームの値
  String? _morningTask;
  String? _afternoonTask;
  String? _healthCondition;
  String? _sleepStatus;
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDropdownOptions();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  /// プルダウンの選択肢を読み込む
  Future<void> _loadDropdownOptions() async {
    try {
      final options = await _masterService.getDropdownOptions();
      setState(() {
        _dropdownOptions = options;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        _showErrorDialog('選択肢の読み込みに失敗しました\n$e');
      }
    }
  }

  /// 出勤登録
  Future<void> _submitCheckin() async {
    // 必須項目のバリデーション
    if (_healthCondition == null || _healthCondition!.isEmpty) {
      _showErrorDialog('本日の体調を選択してください');
      return;
    }
    if (_sleepStatus == null || _sleepStatus!.isEmpty) {
      _showErrorDialog('睡眠状況を選択してください');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final now = DateTime.now();
      final attendance = Attendance(
        date: DateFormat(AppConstants.dateFormat).format(now),
        userName: widget.userName,
        scheduledUse: null,  // 管理者が後から登録
        attendanceStatus: '出勤',
        morningTask: _morningTask,
        afternoonTask: _afternoonTask,
        healthCondition: _healthCondition,
        sleepStatus: _sleepStatus,
        checkinComment: _commentController.text,
        checkinTime: DateFormat(AppConstants.timeFormat).format(now),
        mealService: false,  // 管理者が後から登録
        transportService: false,  // 管理者が後から登録
      );

      await _attendanceService.checkin(attendance);

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'エラーが発生しました';
        if (e.toString().contains('DUPLICATE')) {
          errorMessage = AppConstants.duplicateCheckinMessage;
        }
        _showErrorDialog('$errorMessage\n$e');
      }
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('出勤登録完了'),
        content: const Text('出勤を記録しました。\nお疲れ様です！'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('出勤登録 - ${widget.userName}'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDateTimeDisplay(),
                  const SizedBox(height: 24),
                  _buildFormFields(),
                  const SizedBox(height: 32),
                  _buildSubmitButton(),
                ],
              ),
            ),
    );
  }

  /// 日時表示
  Widget _buildDateTimeDisplay() {
    final now = DateTime.now();
    final dateStr = DateFormat(AppConstants.dateDisplayFormat).format(now);
    final timeStr = DateFormat(AppConstants.timeFormat).format(now);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              dateStr,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              timeStr,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green),
            ),
          ],
        ),
      ),
    );
  }

  /// 入力フォーム
  Widget _buildFormFields() {
    if (_dropdownOptions == null) {
      return const Text('選択肢を読み込めませんでした');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDropdown(
          label: '担当業務（午前）',
          value: _morningTask,
          items: ['', ..._dropdownOptions!.tasks],  // 空白を先頭に追加
          onChanged: (value) => setState(() => _morningTask = value == '' ? null : value),
        ),
        const SizedBox(height: 16),
        _buildDropdown(
          label: '担当業務（午後）',
          value: _afternoonTask,
          items: ['', ..._dropdownOptions!.tasks],  // 空白を先頭に追加
          onChanged: (value) => setState(() => _afternoonTask = value == '' ? null : value),
        ),
        const SizedBox(height: 16),
        _buildDropdown(
          label: '本日の体調 *',
          value: _healthCondition,
          items: _dropdownOptions!.healthCondition,
          onChanged: (value) => setState(() => _healthCondition = value),
        ),
        const SizedBox(height: 16),
        _buildDropdown(
          label: '睡眠状況 *',
          value: _sleepStatus,
          items: _dropdownOptions!.sleepStatus,
          onChanged: (value) => setState(() => _sleepStatus = value),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _commentController,
          decoration: const InputDecoration(
            labelText: 'コメント（任意）',
            border: OutlineInputBorder(),
            hintText: '何かあればお書きください',
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  /// プルダウン部品
  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  /// 出勤ボタン
  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isSubmitting ? null : _submitCheckin,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      child: _isSubmitting
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text('出勤する'),
    );
  }
}
