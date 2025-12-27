import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/attendance.dart';
import '../../models/support_record.dart';
import '../../models/dropdown_options.dart';
import '../../services/attendance_service.dart';
import '../../services/support_service.dart';
import '../../services/master_service.dart';
import '../../config/constants.dart';
import '../../widgets/health_line_chart.dart';

/// 利用者詳細画面（勤怠表示・編集 + 支援記録入力）
class UserDetailScreen extends StatefulWidget {
  final String date;
  final String userName;
  final String? gasUrl; // 施設管理者用（施設固有のGAS URL）

  const UserDetailScreen({
    super.key,
    required this.date,
    required this.userName,
    this.gasUrl,
  });

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  late final AttendanceService _attendanceService;
  late final SupportService _supportService;
  late final MasterService _masterService;
  final _supportFormKey = GlobalKey<FormState>();

  bool _isLoading = true;
  Attendance? _attendance;
  SupportRecord? _supportRecord;
  DropdownOptions? _dropdownOptions;
  String? _errorMessage;
  List<Attendance> _healthHistory = []; // 過去7回分の健康データ
  List<EvaluationAlert> _evaluationAlerts = []; // この利用者の評価アラート

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

  /// 出欠状況が欠勤系（勤務地不要）かどうかを判定
  bool get _isAbsent =>
      _editedAttendanceStatus == '欠勤' ||
      _editedAttendanceStatus == '事前連絡あり欠勤' ||
      _editedAttendanceStatus == '非利用日' ||
      _editedAttendanceStatus == '休養中';
  String? _editedRecorder;      // Dropdown用に変更
  bool _isHomeSupportEval = false;   // 在宅支援評価対象（チェックボックス）
  bool _isExternalEval = false;      // 施設外評価対象（チェックボックス）
  final TextEditingController _workGoalController = TextEditingController();
  String? _editedWorkEval;      // Dropdown用に変更
  String? _editedEmploymentEval; // Dropdown用に変更
  String? _editedWorkMotivation; // Dropdown用に変更
  String? _editedCommunication;  // Dropdown用に変更
  String? _editedEvaluation;     // Dropdown用に変更
  final TextEditingController _userFeedbackController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // サービス初期化（施設管理者の場合はgasUrlを使用）
    _attendanceService = AttendanceService(gasUrl: widget.gasUrl);
    _supportService = SupportService(gasUrl: widget.gasUrl);
    _masterService = MasterService(gasUrl: widget.gasUrl);
    _loadData();
  }

  @override
  void dispose() {
    _userStatusController.dispose();
    _workGoalController.dispose();
    _userFeedbackController.dispose();
    super.dispose();
  }

  /// データ読み込み
  Future<void> _loadData() async {
    try {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final dateStr = DateFormat(AppConstants.dateFormat).format(
        DateFormat(AppConstants.dateFormat).parse(widget.date),
      );

      // 勤怠データ、支援記録、プルダウンオプション、健康履歴、評価アラートを並行取得
      final results = await Future.wait([
        _attendanceService.getUserAttendance(widget.userName, dateStr),
        _supportService.getSupportRecord(dateStr, widget.userName),
        _masterService.getDropdownOptions(),
        _attendanceService.getUserHistory(widget.userName),
        _masterService.getEvaluationAlerts(),
      ]);

      // 非同期処理後のmountedチェック
      if (!mounted) return;

      setState(() {
        _attendance = results[0] as Attendance?;
        _supportRecord = results[1] as SupportRecord?;
        _dropdownOptions = results[2] as DropdownOptions?;
        // 過去7回分の健康データを取得（新しい順）
        final allHistory = results[3] as List<Attendance>;
        _healthHistory = allHistory.take(7).toList();
        // この利用者の評価アラートのみフィルタリング
        final allAlerts = results[4] as List<EvaluationAlert>;
        _evaluationAlerts = allAlerts.where((a) => a.userName == widget.userName).toList();
        _isLoading = false;

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
          // ○が入っていればtrue、それ以外はfalse
          _isHomeSupportEval = _supportRecord!.homeSupportEval == '○';
          _isExternalEval = _supportRecord!.externalEval == '○';
          _workGoalController.text = _supportRecord!.workGoal ?? '';
          _editedWorkEval = _supportRecord!.workEval;
          _editedEmploymentEval = _supportRecord!.employmentEval;
          _editedWorkMotivation = _supportRecord!.workMotivation;
          _editedCommunication = _supportRecord!.communication;
          _editedEvaluation = _supportRecord!.evaluation;
          _userFeedbackController.text = _supportRecord!.userFeedback ?? '';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'データの読み込みに失敗しました\n$e';
        _isLoading = false;
      });
    }
  }

  /// 勤怠データと支援記録を統合保存
  Future<void> _saveAll() async {
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

    // 支援記録の必須項目チェック
    final userStatus = _userStatusController.text.trim();
    if (userStatus.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('「支援記録」を入力してください。'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 欠席でない場合のみ勤務地を必須チェック
    if (!_isAbsent && (_editedWorkLocation == null || _editedWorkLocation!.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('勤務地を選択してください。'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_editedRecorder == null || _editedRecorder!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('記録者を選択してください。'),
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

      // 勤怠データを保存
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

      // 支援記録を保存
      final newRecord = SupportRecord(
        date: widget.date,
        userName: widget.userName,
        userStatus: userStatus,
        workLocation: _editedWorkLocation,
        recorder: _editedRecorder,
        homeSupportEval: _isHomeSupportEval ? '○' : '',
        externalEval: _isExternalEval ? '○' : '',
        workGoal: _workGoalController.text.trim(),
        workEval: _editedWorkEval,
        employmentEval: _editedEmploymentEval,
        workMotivation: _editedWorkMotivation,
        communication: _editedCommunication,
        evaluation: _editedEvaluation,
        userFeedback: _userFeedbackController.text.trim(),
      );

      await _supportService.upsertSupportRecord(newRecord);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('勤怠データと支援記録を保存しました')),
        );
        Navigator.pop(context, true); // 保存後に一覧に戻る
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
                      // 健康推移グラフセクション
                      if (_healthHistory.isNotEmpty) ...[
                        _buildHealthGraphsSection(),
                        const SizedBox(height: 16),
                        const Divider(thickness: 2),
                        const SizedBox(height: 16),
                      ],

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

  /// 健康推移グラフセクション（2列×2段）
  Widget _buildHealthGraphsSection() {
    // 健康履歴を古い順に並べ替え（グラフ表示用）
    final sortedHistory = _healthHistory.reversed.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.show_chart, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            const Text(
              '健康推移（過去7回分）',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 2列×2段のグリッド
        Row(
          children: [
            Expanded(
              child: HealthLineChartCard(
                dataPoints: extractHealthData(sortedHistory, HealthMetricType.healthCondition),
                type: HealthMetricType.healthCondition,
                onTap: () => HealthChartDetailDialog.show(
                  context,
                  dataPoints: extractHealthData(sortedHistory, HealthMetricType.healthCondition),
                  type: HealthMetricType.healthCondition,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: HealthLineChartCard(
                dataPoints: extractHealthData(sortedHistory, HealthMetricType.sleepStatus),
                type: HealthMetricType.sleepStatus,
                onTap: () => HealthChartDetailDialog.show(
                  context,
                  dataPoints: extractHealthData(sortedHistory, HealthMetricType.sleepStatus),
                  type: HealthMetricType.sleepStatus,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: HealthLineChartCard(
                dataPoints: extractHealthData(sortedHistory, HealthMetricType.fatigue),
                type: HealthMetricType.fatigue,
                onTap: () => HealthChartDetailDialog.show(
                  context,
                  dataPoints: extractHealthData(sortedHistory, HealthMetricType.fatigue),
                  type: HealthMetricType.fatigue,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: HealthLineChartCard(
                dataPoints: extractHealthData(sortedHistory, HealthMetricType.stress),
                type: HealthMetricType.stress,
                onTap: () => HealthChartDetailDialog.show(
                  context,
                  dataPoints: extractHealthData(sortedHistory, HealthMetricType.stress),
                  type: HealthMetricType.stress,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 勤怠データセクション
  Widget _buildAttendanceSection() {
    // 勤怠データがない場合は最小限のフォームを表示（欠席登録用）
    if (_attendance == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '勤怠情報（新規登録）',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '利用者の出勤登録がありません。\n出欠状況を選択して登録できます。',
                  style: TextStyle(color: Colors.blue, fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
              // 日時 & 利用者名（横並び）
              _buildTwoColumnRow(
                _buildInfoRow('日時', widget.date),
                _buildInfoRow('利用者名', widget.userName),
              ),
              const SizedBox(height: 16),
              // 出欠（編集可能）
              _buildEditableDropdown(
                '出欠',
                _editedAttendanceStatus,
                _dropdownOptions?.attendanceStatus ?? [],
                (value) => setState(() {
                  _editedAttendanceStatus = value;
                  // 欠勤系に変更した場合は勤務地をクリア
                  if (value == '欠勤' || value == '事前連絡あり欠勤' ||
                      value == '非利用日' || value == '休養中') {
                    _editedWorkLocation = null;
                  }
                }),
                allowNull: false,
              ),
            ],
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
            const Text(
              '勤怠情報',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // 日時 & 利用者名（横並び）
            _buildTwoColumnRow(
              _buildInfoRow('日時', _attendance!.date),
              _buildInfoRow('利用者名', _attendance!.userName),
            ),

            // 出欠（予定） & 出欠（編集可能）（横並び）
            _buildTwoColumnRow(
              _buildInfoRow('出欠（予定）', _attendance!.scheduledUse ?? '-'),
              _buildEditableDropdown(
                '出欠',
                _editedAttendanceStatus,
                _dropdownOptions?.attendanceStatus ?? [],
                (value) => setState(() {
                  _editedAttendanceStatus = value;
                  // 欠勤系に変更した場合は勤務地をクリア
                  if (value == '欠勤' || value == '事前連絡あり欠勤' ||
                      value == '非利用日' || value == '休養中') {
                    _editedWorkLocation = null;
                  }
                }),
                allowNull: false,
              ),
            ),
            const SizedBox(height: 8),

            // 担当業務AM & 担当業務PM（横並び）
            _buildTwoColumnRow(
              _buildInfoRow('担当業務AM', _attendance!.morningTask ?? '-'),
              _buildInfoRow('担当業務PM', _attendance!.afternoonTask ?? '-'),
            ),
            const Divider(),

            // 本日の体調 & 睡眠状況（横並び）
            _buildTwoColumnRow(
              _buildInfoRow('本日の体調', _attendance!.healthCondition ?? '-'),
              _buildInfoRow('睡眠状況', _attendance!.sleepStatus ?? '-'),
            ),

            // 出勤時コメント（幅いっぱい）
            _buildInfoRow('出勤時コメント', _attendance!.checkinComment ?? '-'),
            const Divider(),

            // 疲労感 & 心理的負荷（横並び）
            _buildTwoColumnRow(
              _buildInfoRow('疲労感', _attendance!.fatigue ?? '-'),
              _buildInfoRow('心理的負荷', _attendance!.stress ?? '-'),
            ),

            // 退勤時コメント（幅いっぱい）
            _buildInfoRow('退勤時コメント', _attendance!.checkoutComment ?? '-'),
            const Divider(),

            // 勤務開始時刻 & 勤務終了時刻（横並び、両方編集可能）
            _buildTwoColumnRow(
              _buildEditableDropdown(
                '勤務開始時刻',
                _editedCheckinTime,
                _dropdownOptions?.checkinTimeList ?? [],
                (value) => setState(() => _editedCheckinTime = value),
              ),
              _buildEditableDropdown(
                '勤務終了時刻',
                _editedCheckoutTime,
                _dropdownOptions?.checkoutTimeList ?? [],
                (value) => setState(() => _editedCheckoutTime = value),
              ),
            ),
            const SizedBox(height: 8),

            // 昼休憩 & 15分休憩（横並び、両方編集可能）
            _buildTwoColumnRow(
              _buildEditableDropdown(
                '昼休憩',
                _editedLunchBreak,
                _dropdownOptions?.lunchBreak ?? [],
                (value) => setState(() => _editedLunchBreak = value),
              ),
              _buildEditableDropdown(
                '15分休憩',
                _editedShortBreak,
                _dropdownOptions?.shortBreak ?? [],
                (value) => setState(() => _editedShortBreak = value),
              ),
            ),
            const SizedBox(height: 8),

            // 他休憩時間（編集可能）
            _buildEditableDropdown(
              '他休憩時間',
              _editedOtherBreak,
              _dropdownOptions?.otherBreak ?? [],
              (value) => setState(() => _editedOtherBreak = value),
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
          const SizedBox(height: 8),

          // 評価アラート表示
          if (_evaluationAlerts.isNotEmpty) _buildEvaluationAlertBanner(),

          const SizedBox(height: 16),

          // Z列: 支援記録（幅いっぱい）※必須
          TextFormField(
            controller: _userStatusController,
            decoration: InputDecoration(
              labelText: '支援記録 *',
              labelStyle: TextStyle(color: Colors.red.shade700),
              border: const OutlineInputBorder(),
              hintText: '必須項目です',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),

          // 勤務地 & 記録者（横並び）※勤務地は欠席以外で必須
          _buildTwoColumnRow(
            DropdownButtonFormField<String>(
              value: _isAbsent
                  ? null  // 欠席時は選択値をクリア
                  : (_editedWorkLocation != null &&
                     _editedWorkLocation!.trim().isNotEmpty &&
                     (_dropdownOptions?.workLocations ?? [])
                         .map((e) => e.trim())
                         .toSet()
                         .contains(_editedWorkLocation!.trim())
                      ? _editedWorkLocation!.trim()
                      : null),
              decoration: InputDecoration(
                labelText: _isAbsent ? '勤務地（欠席のため不要）' : '勤務地 *',
                labelStyle: TextStyle(
                  color: _isAbsent ? Colors.grey : Colors.red.shade700,
                ),
                border: const OutlineInputBorder(),
                filled: _isAbsent,
                fillColor: _isAbsent ? Colors.grey.shade200 : null,
              ),
              items: [
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
              onChanged: _isAbsent
                  ? null  // 欠席時は変更不可
                  : (value) => setState(() => _editedWorkLocation = value),
            ),
            DropdownButtonFormField<String>(
              value: _editedRecorder != null &&
                     _editedRecorder!.trim().isNotEmpty &&
                     (_dropdownOptions?.recorders ?? [])
                         .map((e) => e.trim())
                         .toSet()
                         .contains(_editedRecorder!.trim())
                  ? _editedRecorder!.trim()
                  : null,
              decoration: InputDecoration(
                labelText: '記録者 *',
                labelStyle: TextStyle(color: Colors.red.shade700),
                border: const OutlineInputBorder(),
              ),
              items: [
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
          ),
          const SizedBox(height: 16),

          // 在宅支援評価対象 & 施設外評価対象（チェックボックス・横並び・排他的）
          _buildTwoColumnRow(
            CheckboxListTile(
              title: Text(
                '在宅支援評価対象',
                style: TextStyle(
                  color: _isExternalEval ? Colors.grey : null,
                ),
              ),
              value: _isHomeSupportEval,
              onChanged: _isExternalEval
                  ? null  // 施設外がチェックされている場合は無効化
                  : (value) => setState(() => _isHomeSupportEval = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
            CheckboxListTile(
              title: Text(
                '施設外評価対象',
                style: TextStyle(
                  color: _isHomeSupportEval ? Colors.grey : null,
                ),
              ),
              value: _isExternalEval,
              onChanged: _isHomeSupportEval
                  ? null  // 在宅支援がチェックされている場合は無効化
                  : (value) => setState(() => _isExternalEval = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),

          // 条件付き表示：在宅支援評価対象または施設外評価対象がチェックされた場合のみ表示
          if (_isHomeSupportEval || _isExternalEval) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              _isHomeSupportEval && _isExternalEval
                  ? '在宅支援・施設外 評価項目'
                  : _isHomeSupportEval
                      ? '在宅支援 評価項目'
                      : '施設外 評価項目',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 16),

            // 作業目標 & 勤務評価（横並び）
            _buildTwoColumnRow(
              TextFormField(
                controller: _workGoalController,
                decoration: const InputDecoration(
                  labelText: '作業目標',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              DropdownButtonFormField<String>(
                value: _editedWorkEval != null &&
                       _editedWorkEval!.trim().isNotEmpty &&
                       (_dropdownOptions?.workEvaluations ?? [])
                           .map((e) => e.trim())
                           .toSet()
                           .contains(_editedWorkEval!.trim())
                    ? _editedWorkEval!.trim()
                    : null,
                decoration: const InputDecoration(
                  labelText: '勤怠評価',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('選択なし'),
                  ),
                  ...(_dropdownOptions?.workEvaluations ?? [])
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
                onChanged: (value) => setState(() => _editedWorkEval = value),
              ),
            ),
            const SizedBox(height: 16),

            // 通信連絡対応度 & 就労意欲（横並び）
            _buildTwoColumnRow(
              DropdownButtonFormField<String>(
                value: _editedCommunication != null &&
                       _editedCommunication!.trim().isNotEmpty &&
                       (_dropdownOptions?.communications ?? [])
                           .map((e) => e.trim())
                           .toSet()
                           .contains(_editedCommunication!.trim())
                    ? _editedCommunication!.trim()
                    : null,
                decoration: const InputDecoration(
                  labelText: '通信連絡対応度',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('選択なし'),
                  ),
                  ...(_dropdownOptions?.communications ?? [])
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
                onChanged: (value) => setState(() => _editedCommunication = value),
              ),
              DropdownButtonFormField<String>(
                value: _editedWorkMotivation != null &&
                       _editedWorkMotivation!.trim().isNotEmpty &&
                       (_dropdownOptions?.workMotivations ?? [])
                           .map((e) => e.trim())
                           .toSet()
                           .contains(_editedWorkMotivation!.trim())
                    ? _editedWorkMotivation!.trim()
                    : null,
                decoration: const InputDecoration(
                  labelText: '就労意欲',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('選択なし'),
                  ),
                  ...(_dropdownOptions?.workMotivations ?? [])
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
                onChanged: (value) => setState(() => _editedWorkMotivation = value),
              ),
            ),
            const SizedBox(height: 16),

            // 就労評価（品質・生産性）（1列表示 - ラベルが長いため）
            DropdownButtonFormField<String>(
              value: _editedEmploymentEval != null &&
                     _editedEmploymentEval!.trim().isNotEmpty &&
                     (_dropdownOptions?.employmentEvaluations ?? [])
                         .map((e) => e.trim())
                         .toSet()
                         .contains(_editedEmploymentEval!.trim())
                  ? _editedEmploymentEval!.trim()
                  : null,
              decoration: const InputDecoration(
                labelText: '就労評価（品質・生産性）',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('選択なし'),
                ),
                ...(_dropdownOptions?.employmentEvaluations ?? [])
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
              onChanged: (value) => setState(() => _editedEmploymentEval = value),
            ),
            const SizedBox(height: 16),

            // 評価 & 利用者の感想（横並び）
            _buildTwoColumnRow(
              DropdownButtonFormField<String>(
                value: _editedEvaluation != null &&
                       _editedEvaluation!.trim().isNotEmpty &&
                       (_dropdownOptions?.evaluations ?? [])
                           .map((e) => e.trim())
                           .toSet()
                           .contains(_editedEvaluation!.trim())
                    ? _editedEvaluation!.trim()
                    : null,
                decoration: const InputDecoration(
                  labelText: '評価',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('選択なし'),
                  ),
                  ...(_dropdownOptions?.evaluations ?? [])
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
                onChanged: (value) => setState(() => _editedEvaluation = value),
              ),
              TextFormField(
                controller: _userFeedbackController,
                decoration: const InputDecoration(
                  labelText: '利用者の感想',
                  border: OutlineInputBorder(),
                ),
              maxLines: 3,
            ),
          ),
          ], // if (_isHomeSupportEval || _isExternalEval) の閉じカッコ

          const SizedBox(height: 24),

          // 統合保存ボタン
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saveAll,
              icon: const Icon(Icons.save),
              label: const Text('保存'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 2カラムレイアウト用ヘルパー
  Widget _buildTwoColumnRow(Widget left, Widget right) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 画面幅が600px以上なら2カラム、未満なら1カラム
        if (constraints.maxWidth > 600) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: 16),
              Expanded(child: right),
            ],
          );
        } else {
          return Column(
            children: [
              left,
              const SizedBox(height: 16),
              right,
            ],
          );
        }
      },
    );
  }

  /// 評価アラートバナー
  Widget _buildEvaluationAlertBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                '評価アラート',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._evaluationAlerts.map((alert) => Padding(
            padding: const EdgeInsets.only(left: 28, bottom: 4),
            child: Text(
              '• ${alert.message}',
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 13,
              ),
            ),
          )),
        ],
      ),
    );
  }
}
