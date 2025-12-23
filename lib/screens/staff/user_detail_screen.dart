import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/attendance.dart';
import '../../models/support_record.dart';
import '../../models/dropdown_options.dart';
import '../../services/attendance_service.dart';
import '../../services/support_service.dart';
import '../../services/master_service.dart';
import '../../config/constants.dart';

/// 利用者詳細画面（勤怠表示・編集 + 支援記録入力）
class UserDetailScreen extends StatefulWidget {
  final String date;
  final String userName;

  const UserDetailScreen({
    super.key,
    required this.date,
    required this.userName,
  });

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  final SupportService _supportService = SupportService();
  final MasterService _masterService = MasterService();
  final _supportFormKey = GlobalKey<FormState>();

  bool _isLoading = true;
  Attendance? _attendance;
  SupportRecord? _supportRecord;
  DropdownOptions? _dropdownOptions;
  String? _errorMessage;

  // 勤怠編集用の状態変数
  String? _editedAttendanceStatus;
  String? _editedCheckinTime;
  String? _editedCheckoutTime;
  String? _editedLunchBreak;
  String? _editedShortBreak;
  String? _editedOtherBreak;

  // 支援記録入力用コントローラー
  final TextEditingController _userStatusController = TextEditingController();
  String? _editedWorkLocation;  // Dropdown用に変更
  String? _editedRecorder;      // Dropdown用に変更
  final TextEditingController _homeSupportEvalController = TextEditingController();
  final TextEditingController _externalEvalController = TextEditingController();
  final TextEditingController _workGoalController = TextEditingController();
  final TextEditingController _workEvalController = TextEditingController();
  final TextEditingController _employmentEvalController = TextEditingController();
  final TextEditingController _workMotivationController = TextEditingController();
  final TextEditingController _communicationController = TextEditingController();
  final TextEditingController _evaluationController = TextEditingController();
  final TextEditingController _userFeedbackController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _userStatusController.dispose();
    _homeSupportEvalController.dispose();
    _externalEvalController.dispose();
    _workGoalController.dispose();
    _workEvalController.dispose();
    _employmentEvalController.dispose();
    _workMotivationController.dispose();
    _communicationController.dispose();
    _evaluationController.dispose();
    _userFeedbackController.dispose();
    super.dispose();
  }

  /// データ読み込み
  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final dateStr = DateFormat(AppConstants.dateFormat).format(
        DateFormat(AppConstants.dateFormat).parse(widget.date),
      );

      // 勤怠データ、支援記録、プルダウンオプションを並行取得
      final results = await Future.wait([
        _attendanceService.getUserAttendance(widget.userName, dateStr),
        _supportService.getSupportRecord(dateStr, widget.userName),
        _masterService.getDropdownOptions(forceRefresh: true), // キャッシュを使わず強制取得
      ]);

      setState(() {
        _attendance = results[0] as Attendance?;
        _supportRecord = results[1] as SupportRecord?;
        _dropdownOptions = results[2] as DropdownOptions?;
        _isLoading = false;

        // 【デバッグ】勤務地と記録者のデータを確認
        print('📍 勤務地の選択肢数: ${_dropdownOptions?.workLocations.length ?? 0}');
        print('📍 勤務地の内容: ${_dropdownOptions?.workLocations}');
        print('👤 記録者の選択肢数: ${_dropdownOptions?.recorders.length ?? 0}');
        print('👤 記録者の内容: ${_dropdownOptions?.recorders}');

        // 勤怠データがあれば編集用変数に設定（文字列に変換）
        if (_attendance != null) {
          _editedAttendanceStatus = _attendance!.attendanceStatus?.toString();
          _editedCheckinTime = _attendance!.checkinTime?.toString();
          _editedCheckoutTime = _attendance!.checkoutTime?.toString();
          _editedLunchBreak = _attendance!.lunchBreak?.toString();
          _editedShortBreak = _attendance!.shortBreak?.toString();
          _editedOtherBreak = _attendance!.otherBreak?.toString();
        }

        // 支援記録データがあればフィールドに設定
        if (_supportRecord != null) {
          _userStatusController.text = _supportRecord!.userStatus ?? '';
          _editedWorkLocation = _supportRecord!.workLocation;
          _editedRecorder = _supportRecord!.recorder;
          _homeSupportEvalController.text = _supportRecord!.homeSupportEval ?? '';
          _externalEvalController.text = _supportRecord!.externalEval ?? '';
          _workGoalController.text = _supportRecord!.workGoal ?? '';
          _workEvalController.text = _supportRecord!.workEval ?? '';
          _employmentEvalController.text = _supportRecord!.employmentEval ?? '';
          _workMotivationController.text = _supportRecord!.workMotivation ?? '';
          _communicationController.text = _supportRecord!.communication ?? '';
          _evaluationController.text = _supportRecord!.evaluation ?? '';
          _userFeedbackController.text = _supportRecord!.userFeedback ?? '';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'データの読み込みに失敗しました\n$e';
        _isLoading = false;
      });
    }
  }

  /// 勤怠データを保存
  Future<void> _saveAttendance() async {
    if (_attendance == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('勤怠データがありません。'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 出欠の必須チェック
    if (_editedAttendanceStatus == null || _editedAttendanceStatus!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('出欠を選択してください。'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      await _attendanceService.updateAttendance(
        widget.userName,
        widget.date,
        attendanceStatus: _editedAttendanceStatus,
        checkinTime: _editedCheckinTime,
        checkoutTime: _editedCheckoutTime,
        lunchBreak: _editedLunchBreak,
        shortBreak: _editedShortBreak,
        otherBreak: _editedOtherBreak,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('勤怠データを保存しました')),
        );
        _loadData(); // データ再読み込み
      }
    } catch (e) {
      setState(() {
        _errorMessage = '勤怠データの保存に失敗しました\n$e';
        _isLoading = false;
      });
    }
  }

  /// 支援記録を保存
  Future<void> _saveSupportRecord() async {
    if (!_supportFormKey.currentState!.validate()) {
      return;
    }

    if (_attendance == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('勤怠データがありません。先に出勤・退勤登録を行ってください。'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final newRecord = SupportRecord(
        date: widget.date,
        userName: widget.userName,
        userStatus: _userStatusController.text.trim(),
        workLocation: _editedWorkLocation,
        recorder: _editedRecorder,
        homeSupportEval: _homeSupportEvalController.text.trim(),
        externalEval: _externalEvalController.text.trim(),
        workGoal: _workGoalController.text.trim(),
        workEval: _workEvalController.text.trim(),
        employmentEval: _employmentEvalController.text.trim(),
        workMotivation: _workMotivationController.text.trim(),
        communication: _communicationController.text.trim(),
        evaluation: _evaluationController.text.trim(),
        userFeedback: _userFeedbackController.text.trim(),
      );

      await _supportService.upsertSupportRecord(newRecord);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('支援記録を保存しました')),
        );
        _loadData(); // データ再読み込み
      }
    } catch (e) {
      setState(() {
        _errorMessage = '保存に失敗しました\n$e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.userName} - ${widget.date}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('再読み込み'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 勤怠データセクション
                      _buildAttendanceSection(),
                      const SizedBox(height: 24),
                      const Divider(thickness: 2),
                      const SizedBox(height: 24),

                      // 支援記録入力セクション
                      _buildSupportRecordSection(),
                    ],
                  ),
                ),
    );
  }

  /// 勤怠データセクション
  Widget _buildAttendanceSection() {
    if (_attendance == null) {
      return Card(
        color: Colors.orange.shade50,
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            '勤怠データがありません。\n先に出勤・退勤登録を行ってください。',
            style: TextStyle(color: Colors.orange),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '勤怠情報',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _saveAttendance,
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('保存'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('日時', _attendance!.date),
            _buildInfoRow('利用者名', _attendance!.userName),
            _buildInfoRow('出欠（予定）', _attendance!.scheduledUse ?? '-'),
            const SizedBox(height: 8),

            // 編集可能：出欠（必須項目なので"選択なし"なし）
            _buildEditableDropdown(
              '出欠',
              _editedAttendanceStatus,
              _dropdownOptions?.attendanceStatus ?? [],
              (value) => setState(() => _editedAttendanceStatus = value),
              allowNull: false, // 出欠は必須なので"選択なし"を表示しない
            ),
            const SizedBox(height: 8),

            _buildInfoRow('担当業務AM', _attendance!.morningTask ?? '-'),
            _buildInfoRow('担当業務PM', _attendance!.afternoonTask ?? '-'),
            const Divider(),
            _buildInfoRow('本日の体調', _attendance!.healthCondition ?? '-'),
            _buildInfoRow('睡眠状況', _attendance!.sleepStatus ?? '-'),
            _buildInfoRow('出勤時コメント', _attendance!.checkinComment ?? '-'),
            const Divider(),
            _buildInfoRow('疲労感', _attendance!.fatigue ?? '-'),
            _buildInfoRow('心理的負荷', _attendance!.stress ?? '-'),
            _buildInfoRow('退勤時コメント', _attendance!.checkoutComment ?? '-'),
            const Divider(),

            // 編集可能：勤務開始時刻
            _buildEditableDropdown(
              '勤務開始時刻',
              _editedCheckinTime,
              _dropdownOptions?.checkinTimeList ?? [],
              (value) => setState(() => _editedCheckinTime = value),
            ),
            const SizedBox(height: 8),

            // 編集可能：勤務終了時刻
            _buildEditableDropdown(
              '勤務終了時刻',
              _editedCheckoutTime,
              _dropdownOptions?.checkoutTimeList ?? [],
              (value) => setState(() => _editedCheckoutTime = value),
            ),
            const SizedBox(height: 8),

            // 編集可能：昼休憩
            _buildEditableDropdown(
              '昼休憩',
              _editedLunchBreak,
              _dropdownOptions?.lunchBreak ?? [],
              (value) => setState(() => _editedLunchBreak = value),
            ),
            const SizedBox(height: 8),

            // 編集可能：15分休憩
            _buildEditableDropdown(
              '15分休憩',
              _editedShortBreak,
              _dropdownOptions?.shortBreak ?? [],
              (value) => setState(() => _editedShortBreak = value),
            ),
            const SizedBox(height: 8),

            // 編集可能：他休憩時間
            _buildEditableDropdown(
              '他休憩時間',
              _editedOtherBreak,
              _dropdownOptions?.otherBreak ?? [],
              (value) => setState(() => _editedOtherBreak = value),
            ),
            const SizedBox(height: 8),

            _buildInfoRow(
              '実労時間',
              _attendance!.actualWorkMinutes != null
                  ? '${_attendance!.actualWorkMinutes}分'
                  : '-',
            ),
          ],
        ),
      ),
    );
  }

  /// 編集可能なプルダウンフィールド
  Widget _buildEditableDropdown(
    String label,
    String? currentValue,
    List<String> options,
    Function(String?) onChanged, {
    bool allowNull = true, // デフォルトは"選択なし"を表示
  }) {
    // 選択肢を文字列に変換し、空白と重複を除外
    final uniqueOptions = options
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    // 現在値が選択肢に含まれているか確認
    final safeCurrentValue = currentValue != null &&
                             currentValue.toString().trim().isNotEmpty &&
                             uniqueOptions.contains(currentValue.toString().trim())
        ? currentValue.toString().trim()
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: safeCurrentValue,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              items: [
                // allowNullがtrueの場合のみ"選択なし"を表示
                if (allowNull)
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('選択なし'),
                  ),
                ...uniqueOptions.map((option) => DropdownMenuItem<String>(
                      value: option,
                      child: Text(option),
                    )),
              ],
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  /// 情報行を作成
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  /// 支援記録入力セクション
  Widget _buildSupportRecordSection() {
    return Form(
      key: _supportFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '支援記録入力',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Z列: 本人の状況
          TextFormField(
            controller: _userStatusController,
            decoration: const InputDecoration(
              labelText: '本人の状況/欠勤時対応/施設外評価/在宅評価',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),

          // AA列: 勤務地（プルダウン）
          DropdownButtonFormField<String>(
            value: _editedWorkLocation != null &&
                   _editedWorkLocation!.trim().isNotEmpty &&
                   (_dropdownOptions?.workLocations ?? [])
                       .map((e) => e.trim())
                       .toSet()
                       .contains(_editedWorkLocation!.trim())
                ? _editedWorkLocation!.trim()
                : null,
            decoration: const InputDecoration(
              labelText: '勤務地',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('選択なし'),
              ),
              ...(_dropdownOptions?.workLocations ?? [])
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toSet()
                  .map((option) {
                return DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                );
              }),
            ],
            onChanged: (value) => setState(() => _editedWorkLocation = value),
          ),
          const SizedBox(height: 16),

          // AB列: 記録者（プルダウン）
          DropdownButtonFormField<String>(
            value: _editedRecorder != null &&
                   _editedRecorder!.trim().isNotEmpty &&
                   (_dropdownOptions?.recorders ?? [])
                       .map((e) => e.trim())
                       .toSet()
                       .contains(_editedRecorder!.trim())
                ? _editedRecorder!.trim()
                : null,
            decoration: const InputDecoration(
              labelText: '記録者',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('選択なし'),
              ),
              ...(_dropdownOptions?.recorders ?? [])
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toSet()
                  .map((option) {
                return DropdownMenuItem<String>(
                  value: option,
                  child: Text(option),
                );
              }),
            ],
            onChanged: (value) => setState(() => _editedRecorder = value),
          ),
          const SizedBox(height: 16),

          // AD列: 在宅支援評価対象
          TextFormField(
            controller: _homeSupportEvalController,
            decoration: const InputDecoration(
              labelText: '在宅支援評価対象',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),

          // AE列: 施設外評価対象
          TextFormField(
            controller: _externalEvalController,
            decoration: const InputDecoration(
              labelText: '施設外評価対象',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),

          // AF列: 作業目標
          TextFormField(
            controller: _workGoalController,
            decoration: const InputDecoration(
              labelText: '作業目標',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),

          // AG列: 勤務評価
          TextFormField(
            controller: _workEvalController,
            decoration: const InputDecoration(
              labelText: '勤務評価',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),

          // AH列: 就労評価（品質・生産性）
          TextFormField(
            controller: _employmentEvalController,
            decoration: const InputDecoration(
              labelText: '就労評価（品質・生産性）',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),

          // AI列: 就労意欲
          TextFormField(
            controller: _workMotivationController,
            decoration: const InputDecoration(
              labelText: '就労意欲',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),

          // AJ列: 通信連絡対応
          TextFormField(
            controller: _communicationController,
            decoration: const InputDecoration(
              labelText: '通信連絡対応',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),

          // AK列: 評価
          TextFormField(
            controller: _evaluationController,
            decoration: const InputDecoration(
              labelText: '評価',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),

          // AL列: 利用者の感想
          TextFormField(
            controller: _userFeedbackController,
            decoration: const InputDecoration(
              labelText: '利用者の感想',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 24),

          // 保存ボタン
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saveSupportRecord,
              icon: const Icon(Icons.save),
              label: const Text('支援記録を保存'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
