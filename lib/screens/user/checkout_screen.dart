import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/dropdown_options.dart';
import '../../services/attendance_service.dart';
import '../../services/master_service.dart';
import '../../services/master_auth_service.dart';
import '../../config/constants.dart';
import '../../utils/time_utils.dart';

/// 退勤入力画面（利用者用）
class CheckoutScreen extends StatefulWidget {
  final String userName;

  const CheckoutScreen({
    super.key,
    required this.userName,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  final MasterService _masterService = MasterService();

  DropdownOptions? _dropdownOptions;
  bool _isLoading = true;
  bool _isSubmitting = false;

  // 入力フォームの値
  String? _fatigue;
  String? _stress;
  String? _lunchBreak;
  String? _shortBreak;
  String? _otherBreak;
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

  /// 退勤登録
  Future<void> _submitCheckout() async {
    // 必須項目のバリデーション
    if (_fatigue == null || _fatigue!.isEmpty) {
      _showErrorDialog('疲労感を選択してください');
      return;
    }
    if (_stress == null || _stress!.isEmpty) {
      _showErrorDialog('心理的負荷を選択してください');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final now = DateTime.now();
      final dateStr = DateFormat(AppConstants.dateFormat).format(now);
      String checkoutTime = DateFormat(AppConstants.timeFormat).format(now);

      // 時間丸め設定を取得
      final authService = MasterAuthService();
      final timeRounding = await authService.getFacilityTimeRounding();

      // 時間丸め処理（オンの場合のみ）
      if (timeRounding == 'オン' && _dropdownOptions?.checkoutTimeList.isNotEmpty == true) {
        checkoutTime = TimeUtils.roundToNearestTime(
          checkoutTime,
          _dropdownOptions!.checkoutTimeList,
        );
      }

      await _attendanceService.checkout(
        widget.userName,
        dateStr,
        checkoutTime,
        fatigue: _extractNumber(_fatigue),  // 数字部分のみ抽出
        stress: _extractNumber(_stress),    // 数字部分のみ抽出
        lunchBreak: _lunchBreak,
        shortBreak: _shortBreak,
        otherBreak: _otherBreak,
        checkoutComment: _commentController.text,
      );

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'エラーが発生しました';
        if (e.toString().contains('出勤記録が見つかりません')) {
          errorMessage = '本日の出勤記録がありません。先に出勤登録を行ってください。';
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
        title: const Text('退勤登録完了'),
        content: const Text('退勤を記録しました。\nお疲れ様でした！'),
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
        title: Text('退勤登録 - ${widget.userName}'),
        backgroundColor: Colors.blue,
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
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blue),
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
          label: '疲労感 *',
          value: _fatigue,
          items: _dropdownOptions!.fatigue,
          onChanged: (value) => setState(() => _fatigue = value),
        ),
        const SizedBox(height: 16),
        _buildDropdown(
          label: '心理的負荷 *',
          value: _stress,
          items: _dropdownOptions!.stress,
          onChanged: (value) => setState(() => _stress = value),
        ),
        const SizedBox(height: 16),
        _buildDropdown(
          label: '昼休憩（任意）',
          value: _lunchBreak,
          items: ['', ..._dropdownOptions!.lunchBreak],  // 空白を先頭に追加
          onChanged: (value) => setState(() => _lunchBreak = value == '' ? null : value),
        ),
        const SizedBox(height: 16),
        _buildDropdown(
          label: '15分休憩（任意）',
          value: _shortBreak,
          items: ['', ..._dropdownOptions!.shortBreak],  // 空白を先頭に追加
          onChanged: (value) => setState(() => _shortBreak = value == '' ? null : value),
        ),
        const SizedBox(height: 16),
        _buildDropdown(
          label: 'その他休憩（任意）',
          value: _otherBreak,
          items: ['', ..._dropdownOptions!.otherBreak],  // 空白を先頭に追加
          onChanged: (value) => setState(() => _otherBreak = value == '' ? null : value),
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

  /// 退勤ボタン
  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isSubmitting ? null : _submitCheckout,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      child: _isSubmitting
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text('退勤する'),
    );
  }
}
