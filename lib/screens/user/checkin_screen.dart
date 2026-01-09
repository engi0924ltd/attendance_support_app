import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/attendance.dart';
import '../../models/dropdown_options.dart';
import '../../services/attendance_service.dart';
import '../../services/master_service.dart';
import '../../services/master_auth_service.dart';
import '../../config/constants.dart';
import '../../utils/time_utils.dart';
import '../../theme/app_theme_v2.dart';

/// 出勤入力画面（利用者用・V2デザイン）
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

  /// プルダウン値から数字部分だけを抽出
  /// 例: "1（非常に悪い）" -> "1"
  String? _extractNumber(String? value) {
    if (value == null || value.isEmpty) return value;
    final match = RegExp(r'^\d+').firstMatch(value);
    return match != null ? match.group(0) : value;
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
      String checkinTime = DateFormat(AppConstants.timeFormat).format(now);

      // 時間丸め設定を取得
      final authService = MasterAuthService();
      final timeRounding = await authService.getFacilityTimeRounding();

      // 時間丸め処理（オンの場合のみ）
      if (timeRounding == 'オン' && _dropdownOptions?.checkinTimeList.isNotEmpty == true) {
        checkinTime = TimeUtils.roundToNearestTime(
          checkinTime,
          _dropdownOptions!.checkinTimeList,
        );
      }

      final attendance = Attendance(
        date: DateFormat(AppConstants.dateFormat).format(now),
        userName: widget.userName,
        scheduledUse: null,  // 管理者が後から登録
        attendanceStatus: '出勤',
        morningTask: _morningTask,
        afternoonTask: _afternoonTask,
        healthCondition: _extractNumber(_healthCondition),  // 数字部分のみ抽出
        sleepStatus: _extractNumber(_sleepStatus),          // 数字部分のみ抽出
        checkinComment: _commentController.text,
        checkinTime: checkinTime,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: AppThemeV2.successColor, size: 28),
            const SizedBox(width: 8),
            const Text('出勤登録完了'),
          ],
        ),
        content: Image.asset(
          'assets/images/tapir_checkin_success.png',
          height: 300,
          fit: BoxFit.contain,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            child: Text(
              '閉じる',
              style: TextStyle(
                color: AppThemeV2.primaryGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: AppThemeV2.errorColor, size: 28),
            const SizedBox(width: 8),
            const Text('エラー'),
          ],
        ),
        content: Text(message, style: AppThemeV2.bodyLarge),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              '閉じる',
              style: TextStyle(
                color: AppThemeV2.primaryGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CleanScaffold(
      appBar: CleanAppBar(
        title: '出勤登録 - ${widget.userName}',
        backgroundColor: AppThemeV2.primaryGreen,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppThemeV2.primaryGreen,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDateTimeDisplay(),
                  const SizedBox(height: 20),
                  _buildFormFields(),
                  const SizedBox(height: 24),
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

    return CleanCard(
      child: Column(
        children: [
          Text(
            dateStr,
            style: AppThemeV2.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            timeStr,
            style: AppThemeV2.headlineLarge.copyWith(
              color: AppThemeV2.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }

  /// 入力フォーム
  Widget _buildFormFields() {
    if (_dropdownOptions == null) {
      return CleanCard(
        child: Text(
          '選択肢を読み込めませんでした',
          style: AppThemeV2.bodyLarge.copyWith(color: AppThemeV2.errorColor),
        ),
      );
    }

    return CleanCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(
            title: '出勤情報を入力',
            icon: Icons.edit_note,
            iconColor: AppThemeV2.primaryGreen,
          ),
          const SizedBox(height: 8),
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
            isRequired: true,
          ),
          const SizedBox(height: 16),
          _buildDropdown(
            label: '睡眠状況 *',
            value: _sleepStatus,
            items: _dropdownOptions!.sleepStatus,
            onChanged: (value) => setState(() => _sleepStatus = value),
            isRequired: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _commentController,
            decoration: InputDecoration(
              labelText: 'コメント（任意）',
              hintText: '何かあればお書きください',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppThemeV2.primaryGreen, width: 2),
              ),
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  /// プルダウン部品
  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
    bool isRequired = false,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isRequired ? AppThemeV2.primaryGreen : AppThemeV2.textSecondary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppThemeV2.primaryGreen, width: 2),
        ),
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
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitCheckin,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppThemeV2.primaryGreen,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppThemeV2.primaryGreen.withOpacity(0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.login, size: 24),
                  SizedBox(width: 8),
                  Text(
                    '出勤する',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
