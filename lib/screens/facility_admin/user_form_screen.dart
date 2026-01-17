import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../models/dropdown_options.dart';
import '../../services/user_service.dart';
import '../../services/master_service.dart';

/// 利用者登録・編集画面（タブ形式）
class UserFormScreen extends StatefulWidget {
  final User? user; // 編集時は既存の利用者データを渡す
  final String? gasUrl; // 施設固有のGAS URL

  const UserFormScreen({super.key, this.user, this.gasUrl});

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> with SingleTickerProviderStateMixin {
  late final UserService _userService;
  late final MasterService _masterService;
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;

  // プルダウン選択肢
  DropdownOptions? _dropdownOptions;
  bool _isLoadingDropdowns = true;

  // === 基本情報 ===
  late TextEditingController _nameController;
  late TextEditingController _furiganaController;
  String _selectedStatus = '契約中';
  late TextEditingController _postalCodeController;
  late TextEditingController _prefectureController;
  late TextEditingController _cityController;
  late TextEditingController _wardController;
  late TextEditingController _addressController;
  late TextEditingController _address2Controller;
  late TextEditingController _birthDateController;
  late TextEditingController _useStartDateController;

  // 曜日別出欠予定
  late TextEditingController _scheduledMonController;
  late TextEditingController _scheduledTueController;
  late TextEditingController _scheduledWedController;
  late TextEditingController _scheduledThuController;
  late TextEditingController _scheduledFriController;
  late TextEditingController _scheduledSatController;
  late TextEditingController _scheduledSunController;

  // === 連絡先情報 ===
  late TextEditingController _mobilePhoneController;
  late TextEditingController _chatworkIdController;
  late TextEditingController _mailController;
  late TextEditingController _emergencyContact1Controller;
  late TextEditingController _emergencyPhone1Controller;
  late TextEditingController _emergencyContact2Controller;
  late TextEditingController _emergencyPhone2Controller;

  // === 受給者証情報 ===
  late TextEditingController _lifeProtectionController;
  late TextEditingController _disabilityPensionController;
  late TextEditingController _disabilityNumberController;
  late TextEditingController _disabilityGradeController;
  late TextEditingController _disabilityTypeController;
  // 加算項目（ラジオボタン用）
  String _mealSubsidyValue = '';  // 食事提供加算: '○' or ''
  String _transportSubsidyValue = '';  // 送迎加算: '○' or ''
  late TextEditingController _certificateNumberController;
  late TextEditingController _decisionPeriod1Controller;
  late TextEditingController _decisionPeriod2Controller;
  late TextEditingController _applicableStartController;
  late TextEditingController _applicableEndController;
  late TextEditingController _supplyAmountController;
  late TextEditingController _supportLevelController;
  late TextEditingController _userBurdenLimitController;

  // === 銀行口座情報 ===
  late TextEditingController _bankNameController;
  late TextEditingController _bankCodeController;
  late TextEditingController _branchNameController;
  late TextEditingController _branchCodeController;
  late TextEditingController _accountNumberController;

  // === その他情報 ===
  late TextEditingController _consultationFacilityController;
  late TextEditingController _consultationStaffController;
  late TextEditingController _consultationContactController;
  late TextEditingController _ghFacilityController;
  late TextEditingController _ghStaffController;
  late TextEditingController _ghContactController;

  // === 上限管理 ===
  String? _selfManagedValue; // null: 未選択, '○': 自社, '他社': 他社
  late TextEditingController _managementFacilityNameController;
  late TextEditingController _managementFacilityNumberController;

  // === 退所・就労情報 ===
  late TextEditingController _leaveDateController;
  late TextEditingController _leaveReasonController;
  late TextEditingController _workNameController;
  late TextEditingController _workContactController;
  late TextEditingController _workContentController;
  late TextEditingController _contractTypeController;
  late TextEditingController _employmentSupportController;
  late TextEditingController _notesController;

  bool _isLoading = false;
  bool get _isEditMode => widget.user != null;

  @override
  void initState() {
    super.initState();

    // UserServiceを初期化
    _userService = UserService(facilityGasUrl: widget.gasUrl);

    // MasterServiceを初期化
    _masterService = MasterService();

    // TabControllerを初期化（6タブ）
    _tabController = TabController(length: 6, vsync: this);

    // プルダウン選択肢を読み込み
    _loadDropdownOptions();

    // === コントローラーの初期化 ===
    // 基本情報
    _nameController = TextEditingController(text: widget.user?.name ?? '');
    _furiganaController = TextEditingController(text: widget.user?.furigana ?? '');
    _postalCodeController = TextEditingController(text: widget.user?.postalCode ?? '');
    _prefectureController = TextEditingController(text: widget.user?.prefecture ?? '');
    _cityController = TextEditingController(text: widget.user?.city ?? '');
    _wardController = TextEditingController(text: widget.user?.ward ?? '');
    _addressController = TextEditingController(text: widget.user?.address ?? '');
    _address2Controller = TextEditingController(text: widget.user?.address2 ?? '');
    _birthDateController = TextEditingController(text: widget.user?.birthDate ?? '');
    _useStartDateController = TextEditingController(text: widget.user?.useStartDate ?? '');

    // 曜日別出欠予定
    _scheduledMonController = TextEditingController(text: widget.user?.scheduledMon ?? '');
    _scheduledTueController = TextEditingController(text: widget.user?.scheduledTue ?? '');
    _scheduledWedController = TextEditingController(text: widget.user?.scheduledWed ?? '');
    _scheduledThuController = TextEditingController(text: widget.user?.scheduledThu ?? '');
    _scheduledFriController = TextEditingController(text: widget.user?.scheduledFri ?? '');
    _scheduledSatController = TextEditingController(text: widget.user?.scheduledSat ?? '');
    _scheduledSunController = TextEditingController(text: widget.user?.scheduledSun ?? '');

    // 連絡先情報
    _mobilePhoneController = TextEditingController(text: widget.user?.mobilePhone ?? '');
    _chatworkIdController = TextEditingController(text: widget.user?.chatworkId ?? '');
    _mailController = TextEditingController(text: widget.user?.mail ?? '');
    _emergencyContact1Controller = TextEditingController(text: widget.user?.emergencyContact1 ?? '');
    _emergencyPhone1Controller = TextEditingController(text: widget.user?.emergencyPhone1 ?? '');
    _emergencyContact2Controller = TextEditingController(text: widget.user?.emergencyContact2 ?? '');
    _emergencyPhone2Controller = TextEditingController(text: widget.user?.emergencyPhone2 ?? '');

    // 受給者証情報
    _lifeProtectionController = TextEditingController(text: widget.user?.lifeProtection ?? '');
    _disabilityPensionController = TextEditingController(text: widget.user?.disabilityPension ?? '');
    _disabilityNumberController = TextEditingController(text: widget.user?.disabilityNumber ?? '');
    _disabilityGradeController = TextEditingController(text: widget.user?.disabilityGrade ?? '');
    _disabilityTypeController = TextEditingController(text: widget.user?.disabilityType ?? '');
    // 加算項目の初期化
    _mealSubsidyValue = widget.user?.mealSubsidy ?? '';
    _transportSubsidyValue = widget.user?.transportSubsidy ?? '';
    _certificateNumberController = TextEditingController(text: widget.user?.certificateNumber ?? '');
    _decisionPeriod1Controller = TextEditingController(text: widget.user?.decisionPeriod1 ?? '');
    _decisionPeriod2Controller = TextEditingController(text: widget.user?.decisionPeriod2 ?? '');
    _applicableStartController = TextEditingController(text: widget.user?.applicableStart ?? '');
    _applicableEndController = TextEditingController(text: widget.user?.applicableEnd ?? '');
    _supplyAmountController = TextEditingController(text: widget.user?.supplyAmount ?? '');
    _supportLevelController = TextEditingController(text: widget.user?.supportLevel ?? '');
    _userBurdenLimitController = TextEditingController(text: widget.user?.userBurdenLimit ?? '');

    // 銀行口座情報
    _bankNameController = TextEditingController(text: widget.user?.bankName ?? '');
    _bankCodeController = TextEditingController(text: widget.user?.bankCode ?? '');
    _branchNameController = TextEditingController(text: widget.user?.branchName ?? '');
    _branchCodeController = TextEditingController(text: widget.user?.branchCode ?? '');
    _accountNumberController = TextEditingController(text: widget.user?.accountNumber ?? '');

    // その他情報
    _consultationFacilityController = TextEditingController(text: widget.user?.consultationFacility ?? '');
    _consultationStaffController = TextEditingController(text: widget.user?.consultationStaff ?? '');
    _consultationContactController = TextEditingController(text: widget.user?.consultationContact ?? '');
    _ghFacilityController = TextEditingController(text: widget.user?.ghFacility ?? '');
    _ghStaffController = TextEditingController(text: widget.user?.ghStaff ?? '');
    _ghContactController = TextEditingController(text: widget.user?.ghContact ?? '');

    // 上限管理
    final selfManaged = widget.user?.selfManaged;
    final hasFacilityInfo = (widget.user?.managementFacilityName?.isNotEmpty ?? false) ||
                            (widget.user?.managementFacilityNumber?.isNotEmpty ?? false);
    if (selfManaged == '○') {
      _selfManagedValue = '○';
    } else if (hasFacilityInfo) {
      _selfManagedValue = '他社';
    } else {
      _selfManagedValue = null;
    }
    _managementFacilityNameController = TextEditingController(text: widget.user?.managementFacilityName ?? '');
    _managementFacilityNumberController = TextEditingController(text: widget.user?.managementFacilityNumber ?? '');

    // 退所・就労情報
    _leaveDateController = TextEditingController(text: widget.user?.leaveDate ?? '');
    _leaveReasonController = TextEditingController(text: widget.user?.leaveReason ?? '');
    _workNameController = TextEditingController(text: widget.user?.workName ?? '');
    _workContactController = TextEditingController(text: widget.user?.workContact ?? '');
    _workContentController = TextEditingController(text: widget.user?.workContent ?? '');
    _contractTypeController = TextEditingController(text: widget.user?.contractType ?? '');
    _employmentSupportController = TextEditingController(text: widget.user?.employmentSupport ?? '');
    _notesController = TextEditingController(text: widget.user?.notes ?? '');

    if (widget.user != null) {
      _selectedStatus = widget.user!.status;
    }

    // 退所日が入力されている場合の監視
    _leaveDateController.addListener(() {
      setState(() {}); // 退所日の入力状態に応じてUIを更新
    });
  }

  /// プルダウン選択肢を読み込む
  Future<void> _loadDropdownOptions() async {
    try {
      final options = await _masterService.getDropdownOptions();

      setState(() {
        _dropdownOptions = options;
        _isLoadingDropdowns = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingDropdowns = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('プルダウン選択肢の読み込みに失敗しました: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    // 基本情報
    _nameController.dispose();
    _furiganaController.dispose();
    _postalCodeController.dispose();
    _prefectureController.dispose();
    _cityController.dispose();
    _wardController.dispose();
    _addressController.dispose();
    _address2Controller.dispose();
    _birthDateController.dispose();
    _useStartDateController.dispose();
    // 曜日別出欠予定
    _scheduledMonController.dispose();
    _scheduledTueController.dispose();
    _scheduledWedController.dispose();
    _scheduledThuController.dispose();
    _scheduledFriController.dispose();
    _scheduledSatController.dispose();
    _scheduledSunController.dispose();
    // 連絡先情報
    _mobilePhoneController.dispose();
    _chatworkIdController.dispose();
    _mailController.dispose();
    _emergencyContact1Controller.dispose();
    _emergencyPhone1Controller.dispose();
    _emergencyContact2Controller.dispose();
    _emergencyPhone2Controller.dispose();
    // 受給者証情報
    _lifeProtectionController.dispose();
    _disabilityPensionController.dispose();
    _disabilityNumberController.dispose();
    _disabilityGradeController.dispose();
    _disabilityTypeController.dispose();
    _certificateNumberController.dispose();
    _decisionPeriod1Controller.dispose();
    _decisionPeriod2Controller.dispose();
    _applicableStartController.dispose();
    _applicableEndController.dispose();
    _supplyAmountController.dispose();
    _supportLevelController.dispose();
    _userBurdenLimitController.dispose();
    // 銀行口座情報
    _bankNameController.dispose();
    _bankCodeController.dispose();
    _branchNameController.dispose();
    _branchCodeController.dispose();
    _accountNumberController.dispose();
    // その他情報
    _consultationFacilityController.dispose();
    _consultationStaffController.dispose();
    _consultationContactController.dispose();
    _ghFacilityController.dispose();
    _ghStaffController.dispose();
    _ghContactController.dispose();
    // 上限管理
    _managementFacilityNameController.dispose();
    _managementFacilityNumberController.dispose();
    // 退所・就労情報
    _leaveDateController.dispose();
    _leaveReasonController.dispose();
    _workNameController.dispose();
    _workContactController.dispose();
    _workContentController.dispose();
    _contractTypeController.dispose();
    _employmentSupportController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isEditMode) {
        // 更新
        await _userService.updateUser(
          rowNumber: widget.user!.rowNumber!,
          name: _nameController.text.trim(),
          furigana: _furiganaController.text.trim(),
          status: _selectedStatus,
          // 曜日別出欠予定
          scheduledMon: _scheduledMonController.text.trim(),
          scheduledTue: _scheduledTueController.text.trim(),
          scheduledWed: _scheduledWedController.text.trim(),
          scheduledThu: _scheduledThuController.text.trim(),
          scheduledFri: _scheduledFriController.text.trim(),
          scheduledSat: _scheduledSatController.text.trim(),
          scheduledSun: _scheduledSunController.text.trim(),
          // 連絡先情報
          mobilePhone: _mobilePhoneController.text.trim(),
          chatworkId: _chatworkIdController.text.trim(),
          mail: _mailController.text.trim(),
          emergencyContact1: _emergencyContact1Controller.text.trim(),
          emergencyPhone1: _emergencyPhone1Controller.text.trim(),
          emergencyContact2: _emergencyContact2Controller.text.trim(),
          emergencyPhone2: _emergencyPhone2Controller.text.trim(),
          // 住所情報
          postalCode: _postalCodeController.text.trim(),
          prefecture: _prefectureController.text.trim(),
          city: _cityController.text.trim(),
          ward: _wardController.text.trim(),
          address: _addressController.text.trim(),
          address2: _address2Controller.text.trim(),
          // 詳細情報
          birthDate: _birthDateController.text.trim(),
          lifeProtection: _lifeProtectionController.text.trim(),
          disabilityPension: _disabilityPensionController.text.trim(),
          disabilityNumber: _disabilityNumberController.text.trim(),
          disabilityGrade: _disabilityGradeController.text.trim(),
          disabilityType: _disabilityTypeController.text.trim(),
          mealSubsidy: _mealSubsidyValue,
          transportSubsidy: _transportSubsidyValue,
          certificateNumber: _certificateNumberController.text.trim(),
          decisionPeriod1: _decisionPeriod1Controller.text.trim(),
          decisionPeriod2: _decisionPeriod2Controller.text.trim(),
          applicableStart: _applicableStartController.text.trim(),
          applicableEnd: _applicableEndController.text.trim(),
          supplyAmount: _supplyAmountController.text.trim(),
          supportLevel: _supportLevelController.text.trim(),
          userBurdenLimit: _userBurdenLimitController.text.trim(),
          useStartDate: _useStartDateController.text.trim(),
          // 相談支援事業所
          consultationFacility: _consultationFacilityController.text.trim(),
          consultationStaff: _consultationStaffController.text.trim(),
          consultationContact: _consultationContactController.text.trim(),
          // グループホーム
          ghFacility: _ghFacilityController.text.trim(),
          ghStaff: _ghStaffController.text.trim(),
          ghContact: _ghContactController.text.trim(),
          // 上限管理
          selfManaged: _selfManagedValue == '○' ? '○' : '',
          managementFacilityName: _selfManagedValue != null ? _managementFacilityNameController.text.trim() : '',
          managementFacilityNumber: _selfManagedValue != null ? _managementFacilityNumberController.text.trim() : '',
          // 銀行口座情報
          bankName: _bankNameController.text.trim(),
          bankCode: _bankCodeController.text.trim(),
          branchName: _branchNameController.text.trim(),
          branchCode: _branchCodeController.text.trim(),
          accountNumber: _accountNumberController.text.trim(),
          // 退所・就労情報
          leaveDate: _leaveDateController.text.trim(),
          leaveReason: _leaveReasonController.text.trim(),
          workName: _workNameController.text.trim(),
          workContact: _workContactController.text.trim(),
          workContent: _workContentController.text.trim(),
          contractType: _contractTypeController.text.trim(),
          employmentSupport: _employmentSupportController.text.trim(),
          notes: _notesController.text.trim(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('利用者情報を更新しました')),
          );
          Navigator.pop(context, true);
        }
      } else {
        // 新規登録
        await _userService.createUser(
          name: _nameController.text.trim(),
          furigana: _furiganaController.text.trim(),
          status: _selectedStatus,
          // 曜日別出欠予定
          scheduledMon: _scheduledMonController.text.trim(),
          scheduledTue: _scheduledTueController.text.trim(),
          scheduledWed: _scheduledWedController.text.trim(),
          scheduledThu: _scheduledThuController.text.trim(),
          scheduledFri: _scheduledFriController.text.trim(),
          scheduledSat: _scheduledSatController.text.trim(),
          scheduledSun: _scheduledSunController.text.trim(),
          // 連絡先情報
          mobilePhone: _mobilePhoneController.text.trim(),
          chatworkId: _chatworkIdController.text.trim(),
          mail: _mailController.text.trim(),
          emergencyContact1: _emergencyContact1Controller.text.trim(),
          emergencyPhone1: _emergencyPhone1Controller.text.trim(),
          emergencyContact2: _emergencyContact2Controller.text.trim(),
          emergencyPhone2: _emergencyPhone2Controller.text.trim(),
          // 住所情報
          postalCode: _postalCodeController.text.trim(),
          prefecture: _prefectureController.text.trim(),
          city: _cityController.text.trim(),
          ward: _wardController.text.trim(),
          address: _addressController.text.trim(),
          address2: _address2Controller.text.trim(),
          // 詳細情報
          birthDate: _birthDateController.text.trim(),
          lifeProtection: _lifeProtectionController.text.trim(),
          disabilityPension: _disabilityPensionController.text.trim(),
          disabilityNumber: _disabilityNumberController.text.trim(),
          disabilityGrade: _disabilityGradeController.text.trim(),
          disabilityType: _disabilityTypeController.text.trim(),
          mealSubsidy: _mealSubsidyValue,
          transportSubsidy: _transportSubsidyValue,
          certificateNumber: _certificateNumberController.text.trim(),
          decisionPeriod1: _decisionPeriod1Controller.text.trim(),
          decisionPeriod2: _decisionPeriod2Controller.text.trim(),
          applicableStart: _applicableStartController.text.trim(),
          applicableEnd: _applicableEndController.text.trim(),
          supplyAmount: _supplyAmountController.text.trim(),
          supportLevel: _supportLevelController.text.trim(),
          userBurdenLimit: _userBurdenLimitController.text.trim(),
          useStartDate: _useStartDateController.text.trim(),
          // 相談支援事業所
          consultationFacility: _consultationFacilityController.text.trim(),
          consultationStaff: _consultationStaffController.text.trim(),
          consultationContact: _consultationContactController.text.trim(),
          // グループホーム
          ghFacility: _ghFacilityController.text.trim(),
          ghStaff: _ghStaffController.text.trim(),
          ghContact: _ghContactController.text.trim(),
          // 上限管理
          selfManaged: _selfManagedValue == '○' ? '○' : '',
          managementFacilityName: _selfManagedValue != null ? _managementFacilityNameController.text.trim() : '',
          managementFacilityNumber: _selfManagedValue != null ? _managementFacilityNumberController.text.trim() : '',
          // 銀行口座情報
          bankName: _bankNameController.text.trim(),
          bankCode: _bankCodeController.text.trim(),
          branchName: _branchNameController.text.trim(),
          branchCode: _branchCodeController.text.trim(),
          accountNumber: _accountNumberController.text.trim(),
          // 退所・就労情報
          leaveDate: _leaveDateController.text.trim(),
          leaveReason: _leaveReasonController.text.trim(),
          workName: _workNameController.text.trim(),
          workContact: _workContactController.text.trim(),
          workContent: _workContentController.text.trim(),
          contractType: _contractTypeController.text.trim(),
          employmentSupport: _employmentSupportController.text.trim(),
          notes: _notesController.text.trim(),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('利用者を登録しました')),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? '利用者情報編集' : '利用者登録'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: '基本情報'),
            Tab(icon: Icon(Icons.contact_phone), text: '連絡先'),
            Tab(icon: Icon(Icons.medical_services), text: '受給者証'),
            Tab(icon: Icon(Icons.account_balance), text: '銀行口座'),
            Tab(icon: Icon(Icons.business), text: 'その他'),
            Tab(icon: Icon(Icons.exit_to_app), text: '退所・就労'),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildBasicInfoTab(),
            _buildContactInfoTab(),
            _buildCertificateInfoTab(),
            _buildBankInfoTab(),
            _buildOtherInfoTab(),
            _buildRetirementInfoTab(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _submit,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check),
            label: Text(_isLoading
                ? '処理中...'
                : _isEditMode
                    ? '更新'
                    : '登録'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // === タブ1: 基本情報 ===
  Widget _buildBasicInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 説明カード
          Card(
            color: Colors.purple.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '基本情報',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '※マークは必須項目です',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 利用者名 ※必須
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '利用者名 ※',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
              hintText: '例: 山田太郎',
            ),
            enabled: !_isLoading,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '利用者名を入力してください';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // フリガナ ※必須
          TextFormField(
            controller: _furiganaController,
            decoration: const InputDecoration(
              labelText: 'フリガナ ※',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.text_fields),
              hintText: '例: ヤマダタロウ',
            ),
            enabled: !_isLoading,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'フリガナを入力してください';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // 契約状態 ※必須
          _isLoadingDropdowns
              ? TextFormField(
                  decoration: const InputDecoration(
                    labelText: '契約状態 ※',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.assignment_turned_in),
                    hintText: '読み込み中...',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  ),
                  enabled: false,
                )
              : DropdownButtonFormField<String>(
                  value: (_dropdownOptions?.rosterStatus ?? []).contains(_selectedStatus)
                      ? _selectedStatus
                      : null,
                  decoration: const InputDecoration(
                    labelText: '契約状態 ※',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.assignment_turned_in),
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('（未選択）'),
                    ),
                    ...(_dropdownOptions?.rosterStatus ?? []).map((option) {
                      return DropdownMenuItem<String>(
                        value: option,
                        child: Text(option),
                      );
                    }),
                  ],
                  onChanged: _isLoading
                      ? null
                      : (value) {
                          setState(() {
                            _selectedStatus = value ?? '';
                          });
                        },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '契約状態を選択してください';
                    }
                    return null;
                  },
                ),
          const SizedBox(height: 24),

          // 加算項目セクション
          const Text(
            '加算項目',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // 食事提供加算の有無
          _buildSubsidyRadioGroup(
            label: '食事提供加算の有無 ※',
            value: _mealSubsidyValue,
            onChanged: (val) => setState(() => _mealSubsidyValue = val),
          ),
          const SizedBox(height: 16),

          // 送迎加算の有無
          _buildSubsidyRadioGroup(
            label: '送迎加算の有無 ※',
            value: _transportSubsidyValue,
            onChanged: (val) => setState(() => _transportSubsidyValue = val),
          ),
          const SizedBox(height: 24),

          // 住所情報セクション
          const Text(
            '住所情報',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // 郵便番号
          TextFormField(
            controller: _postalCodeController,
            decoration: const InputDecoration(
              labelText: '郵便番号',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.markunread_mailbox),
              hintText: '例: 123-4567',
            ),
            enabled: !_isLoading,
          ),
          const SizedBox(height: 16),

          // 都道府県 ※必須
          TextFormField(
            controller: _prefectureController,
            decoration: const InputDecoration(
              labelText: '都道府県 ※',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.location_on),
              hintText: '例: 東京都',
            ),
            enabled: !_isLoading,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '都道府県を入力してください';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // 市区町村 ※必須
          TextFormField(
            controller: _cityController,
            decoration: const InputDecoration(
              labelText: '市区町村 ※',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.location_city),
              hintText: '例: 渋谷区',
            ),
            enabled: !_isLoading,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '市区町村を入力してください';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // 政令指定都市区名
          TextFormField(
            controller: _wardController,
            decoration: const InputDecoration(
              labelText: '政令指定都市区名',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.location_city),
              hintText: '例: 中央区（政令市の場合）',
            ),
            enabled: !_isLoading,
          ),
          const SizedBox(height: 16),

          // 住所 ※必須
          TextFormField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: '住所 ※',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.home),
              hintText: '例: 道玄坂1-2-3',
            ),
            enabled: !_isLoading,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '住所を入力してください';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // 住所2（転居先など）
          TextFormField(
            controller: _address2Controller,
            decoration: const InputDecoration(
              labelText: '住所2（転居先など）',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.home_outlined),
              hintText: '例: マンション名・部屋番号',
            ),
            enabled: !_isLoading,
          ),
          const SizedBox(height: 24),

          // その他基本情報
          const Text(
            'その他基本情報',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // 生年月日
          TextFormField(
            controller: _birthDateController,
            decoration: const InputDecoration(
              labelText: '生年月日',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.cake),
              hintText: '例: 19900101（8桁の数字）',
              counterText: '',
            ),
            keyboardType: TextInputType.number,
            maxLength: 8,
            enabled: !_isLoading,
          ),
          const SizedBox(height: 16),

          // 利用開始日 ※必須
          TextFormField(
            controller: _useStartDateController,
            decoration: const InputDecoration(
              labelText: '利用開始日 ※',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.event),
              hintText: '例: 20250101（8桁の数字）',
              counterText: '',
            ),
            keyboardType: TextInputType.number,
            maxLength: 8,
            enabled: !_isLoading,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '利用開始日を入力してください';
              }
              if (value.trim().length != 8) {
                return '8桁の数字で入力してください';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // 曜日別出欠予定セクション
          const Text(
            '曜日別出欠予定',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // 月曜日
          _buildWeeklyScheduleDropdown(
            label: '月曜日',
            controller: _scheduledMonController,
          ),
          const SizedBox(height: 12),

          // 火曜日
          _buildWeeklyScheduleDropdown(
            label: '火曜日',
            controller: _scheduledTueController,
          ),
          const SizedBox(height: 12),

          // 水曜日
          _buildWeeklyScheduleDropdown(
            label: '水曜日',
            controller: _scheduledWedController,
          ),
          const SizedBox(height: 12),

          // 木曜日
          _buildWeeklyScheduleDropdown(
            label: '木曜日',
            controller: _scheduledThuController,
          ),
          const SizedBox(height: 12),

          // 金曜日
          _buildWeeklyScheduleDropdown(
            label: '金曜日',
            controller: _scheduledFriController,
          ),
          const SizedBox(height: 12),

          // 土曜日
          _buildWeeklyScheduleDropdown(
            label: '土曜日',
            controller: _scheduledSatController,
          ),
          const SizedBox(height: 12),

          // 日曜日
          _buildWeeklyScheduleDropdown(
            label: '日曜日',
            controller: _scheduledSunController,
          ),
          const SizedBox(height: 80), // ボタン分のスペース確保
        ],
      ),
    );
  }

  // === タブ2: 連絡先情報 ===
  Widget _buildContactInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: Colors.purple.shade50,
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                '連絡先情報',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 携帯電話番号
          TextFormField(
            controller: _mobilePhoneController,
            decoration: const InputDecoration(
              labelText: '携帯電話番号',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone_android),
              hintText: '例: 090-1234-5678',
            ),
            enabled: !_isLoading,
          ),
          const SizedBox(height: 16),

          // ChatWorkルームID
          TextFormField(
            controller: _chatworkIdController,
            decoration: const InputDecoration(
              labelText: 'ChatWorkルームID',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.chat),
              hintText: '例: 123456789',
            ),
            enabled: !_isLoading,
          ),
          const SizedBox(height: 16),

          // メールアドレス
          TextFormField(
            controller: _mailController,
            decoration: const InputDecoration(
              labelText: 'メールアドレス',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email),
              hintText: '例: example@example.com',
            ),
            enabled: !_isLoading,
          ),
          const SizedBox(height: 24),

          // 緊急連絡先1
          const Text(
            '緊急連絡先1',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          TextFormField(
            controller: _emergencyContact1Controller,
            decoration: const InputDecoration(
              labelText: '連絡先名',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.emergency),
              hintText: '例: 父、母',
            ),
            enabled: !_isLoading,
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _emergencyPhone1Controller,
            decoration: const InputDecoration(
              labelText: '電話番号',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
              hintText: '例: 090-1234-5678',
            ),
            enabled: !_isLoading,
          ),
          const SizedBox(height: 24),

          // 緊急連絡先2
          const Text(
            '緊急連絡先2',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          TextFormField(
            controller: _emergencyContact2Controller,
            decoration: const InputDecoration(
              labelText: '連絡先名',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.emergency),
              hintText: '例: 兄弟、親戚',
            ),
            enabled: !_isLoading,
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _emergencyPhone2Controller,
            decoration: const InputDecoration(
              labelText: '電話番号',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
              hintText: '例: 090-1234-5678',
            ),
            enabled: !_isLoading,
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // === タブ3: 受給者証情報 ===
  Widget _buildCertificateInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: Colors.purple.shade50,
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                '受給者証情報',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 生活保護
          _buildDropdown(
            label: '生活保護',
            controller: _lifeProtectionController,
            options: _dropdownOptions?.lifeProtection ?? [],
            icon: Icons.security,
          ),
          const SizedBox(height: 16),

          // 障がい者手帳年金
          _buildDropdown(
            label: '障がい者手帳年金',
            controller: _disabilityPensionController,
            options: _dropdownOptions?.disabilityPension ?? [],
            icon: Icons.credit_card,
          ),
          const SizedBox(height: 16),

          // 障害者手帳番号
          TextFormField(
            controller: _disabilityNumberController,
            decoration: const InputDecoration(
              labelText: '障害者手帳番号',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.confirmation_number),
            ),
            enabled: !_isLoading,
          ),
          const SizedBox(height: 16),

          // 障害等級
          _buildDropdown(
            label: '障害等級',
            controller: _disabilityGradeController,
            options: _dropdownOptions?.disabilityGrade ?? [],
            icon: Icons.stairs,
          ),
          const SizedBox(height: 16),

          // 障害種別
          _buildDropdown(
            label: '障害種別',
            controller: _disabilityTypeController,
            options: _dropdownOptions?.disabilityType ?? [],
            icon: Icons.category,
          ),
          const SizedBox(height: 16),

          // 受給者証番号等
          TextFormField(
            controller: _certificateNumberController,
            decoration: const InputDecoration(
              labelText: '受給者証番号等',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.badge),
            ),
            enabled: !_isLoading,
          ),
          const SizedBox(height: 16),

          // 支給決定期間1
          TextFormField(
            controller: _decisionPeriod1Controller,
            decoration: const InputDecoration(
              labelText: '支給決定期間（開始）',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.calendar_month),
              hintText: '例: 20250401（8桁の数字）',
              counterText: '',
            ),
            keyboardType: TextInputType.number,
            maxLength: 8,
            enabled: !_isLoading,
          ),
          const SizedBox(height: 16),

          // 支給決定期間2
          TextFormField(
            controller: _decisionPeriod2Controller,
            decoration: const InputDecoration(
              labelText: '支給決定期間（終了）',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.calendar_month),
              hintText: '例: 20260331（8桁の数字）',
              counterText: '',
            ),
            keyboardType: TextInputType.number,
            maxLength: 8,
            enabled: !_isLoading,
          ),
          const SizedBox(height: 16),

          // 適用期間開始日
          TextFormField(
            controller: _applicableStartController,
            decoration: const InputDecoration(
              labelText: '適用期間開始日',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.event_available),
              hintText: '例: 20250401（8桁の数字）',
              counterText: '',
            ),
            keyboardType: TextInputType.number,
            maxLength: 8,
            enabled: !_isLoading,
          ),
          const SizedBox(height: 16),

          // 適用期間有効期限
          TextFormField(
            controller: _applicableEndController,
            decoration: const InputDecoration(
              labelText: '適用期間有効期限',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.event_busy),
              hintText: '例: 20260331（8桁の数字）',
              counterText: '',
            ),
            keyboardType: TextInputType.number,
            maxLength: 8,
            enabled: !_isLoading,
          ),
          const SizedBox(height: 16),

          // 支給量
          TextFormField(
            controller: _supplyAmountController,
            decoration: const InputDecoration(
              labelText: '支給量',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.format_list_numbered),
            ),
            enabled: !_isLoading,
          ),
          const SizedBox(height: 16),

          // 障害支援区分
          _buildDropdown(
            label: '障害支援区分',
            controller: _supportLevelController,
            options: _dropdownOptions?.supportLevel ?? [],
            icon: Icons.support,
          ),
          const SizedBox(height: 16),

          // 利用者負担上限月額
          TextFormField(
            controller: _userBurdenLimitController,
            decoration: const InputDecoration(
              labelText: '利用者負担上限月額',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.payments),
              suffixText: '円',
            ),
            keyboardType: TextInputType.number,
            enabled: !_isLoading,
          ),
          const SizedBox(height: 24),

          // 上限管理
          const Text(
            '上限管理',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          // 自社/他社 チェックボックス（排他制御）
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  title: const Text('自社で行う'),
                  value: _selfManagedValue == '○',
                  onChanged: _isLoading ? null : (value) {
                    setState(() {
                      if (value == true) {
                        _selfManagedValue = '○';
                      } else {
                        _selfManagedValue = null;
                      }
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
              Expanded(
                child: CheckboxListTile(
                  title: const Text('他社で行う'),
                  value: _selfManagedValue == '他社',
                  onChanged: _isLoading ? null : (value) {
                    setState(() {
                      if (value == true) {
                        _selfManagedValue = '他社';
                      } else {
                        _selfManagedValue = null;
                      }
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _managementFacilityNameController,
            decoration: InputDecoration(
              labelText: '施設名',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.apartment),
              filled: _selfManagedValue == null,
              fillColor: Colors.grey.shade200,
            ),
            enabled: !_isLoading && _selfManagedValue != null,
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _managementFacilityNumberController,
            decoration: InputDecoration(
              labelText: '施設番号',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.numbers),
              filled: _selfManagedValue == null,
              fillColor: Colors.grey.shade200,
            ),
            enabled: !_isLoading && _selfManagedValue != null,
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // === タブ4: 銀行口座情報 ===
  Widget _buildBankInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: Colors.purple.shade50,
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                '銀行口座情報（工賃振込先）',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 銀行名
          TextFormField(
            controller: _bankNameController,
            decoration: const InputDecoration(
              labelText: '銀行名',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.account_balance),
              hintText: '例: ○○銀行',
            ),
            enabled: !_isLoading,
          ),
          const SizedBox(height: 16),

          // 金融機関コード
          TextFormField(
            controller: _bankCodeController,
            decoration: const InputDecoration(
              labelText: '金融機関コード',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.numbers),
              hintText: '例: 0001',
            ),
            enabled: !_isLoading,
          ),
          const SizedBox(height: 16),

          // 支店名
          TextFormField(
            controller: _branchNameController,
            decoration: const InputDecoration(
              labelText: '支店名',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.store),
              hintText: '例: ○○支店',
            ),
            enabled: !_isLoading,
          ),
          const SizedBox(height: 16),

          // 支店番号
          TextFormField(
            controller: _branchCodeController,
            decoration: const InputDecoration(
              labelText: '支店番号',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.numbers),
              hintText: '例: 001',
            ),
            enabled: !_isLoading,
          ),
          const SizedBox(height: 16),

          // 口座番号
          TextFormField(
            controller: _accountNumberController,
            decoration: const InputDecoration(
              labelText: '口座番号',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.pin),
              hintText: '例: 1234567',
            ),
            enabled: !_isLoading,
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // === タブ5: その他情報 ===
  Widget _buildOtherInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: Colors.purple.shade50,
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'その他関係機関情報',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 相談支援事業所
          const Text(
            '相談支援事業所',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          TextFormField(
            controller: _consultationFacilityController,
            decoration: const InputDecoration(
              labelText: '施設名',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.business),
            ),
            enabled: !_isLoading,
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _consultationStaffController,
            decoration: const InputDecoration(
              labelText: '担当者名',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            enabled: !_isLoading,
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _consultationContactController,
            decoration: const InputDecoration(
              labelText: '連絡先',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
            ),
            enabled: !_isLoading,
          ),
          const SizedBox(height: 24),

          // グループホーム
          const Text(
            'グループホーム',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          TextFormField(
            controller: _ghFacilityController,
            decoration: const InputDecoration(
              labelText: '施設名',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.home_work),
            ),
            enabled: !_isLoading,
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _ghStaffController,
            decoration: const InputDecoration(
              labelText: '担当者名',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            enabled: !_isLoading,
          ),
          const SizedBox(height: 12),

          TextFormField(
            controller: _ghContactController,
            decoration: const InputDecoration(
              labelText: '連絡先',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
            ),
            enabled: !_isLoading,
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // === タブ6: 退所・就労情報 ===
  Widget _buildRetirementInfoTab() {
    // 退所日が入力されているかチェック
    final hasLeaveDate = _leaveDateController.text.trim().isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: Colors.purple.shade50,
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                '退所・就労情報',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 退所日（必須入力フィールド）
          TextFormField(
            controller: _leaveDateController,
            decoration: const InputDecoration(
              labelText: '退所日',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.event),
              hintText: '例: 20251231（8桁の数字）',
              helperText: '※退所日を入力すると、その他の退所情報を入力できます',
              counterText: '',
            ),
            keyboardType: TextInputType.number,
            maxLength: 8,
            enabled: !_isLoading,
            onChanged: (value) {
              setState(() {}); // 入力状態に応じてUIを更新
            },
          ),
          const SizedBox(height: 24),

          // 退所日が入力されている場合のみ表示
          if (hasLeaveDate) ...[
            // 退所理由
            TextFormField(
              controller: _leaveReasonController,
              decoration: const InputDecoration(
                labelText: '退所理由',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              enabled: !_isLoading,
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // 勤務先名称
            TextFormField(
              controller: _workNameController,
              decoration: const InputDecoration(
                labelText: '勤務先 名称',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.work),
              ),
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),

            // 勤務先連絡先
            TextFormField(
              controller: _workContactController,
              decoration: const InputDecoration(
                labelText: '勤務先 連絡先',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),

            // 業務内容
            TextFormField(
              controller: _workContentController,
              decoration: const InputDecoration(
                labelText: '業務内容',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.work_outline),
              ),
              enabled: !_isLoading,
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // 契約形態
            _buildDropdown(
              label: '契約形態',
              controller: _contractTypeController,
              options: _dropdownOptions?.contractType ?? [],
              icon: Icons.assignment,
              hintText: '例: 正社員、パート、契約社員',
            ),
            const SizedBox(height: 16),

            // 定着支援 有無
            _buildDropdown(
              label: '定着支援 有無',
              controller: _employmentSupportController,
              options: _dropdownOptions?.employmentSupport ?? [],
              icon: Icons.support_agent,
              hintText: '例: あり、なし',
            ),
            const SizedBox(height: 16),

            // 配慮事項
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: '配慮事項',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
              enabled: !_isLoading,
              maxLines: 5,
            ),
          ] else ...[
            // 退所日未入力時のメッセージ
            Center(
              child: Column(
                children: [
                  Icon(Icons.info_outline, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    '退所日を入力すると、\n退所・就労情報を入力できます',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  /// 曜日別出欠予定のドロップダウンを生成
  Widget _buildWeeklyScheduleDropdown({
    required String label,
    required TextEditingController controller,
  }) {
    return _buildDropdown(
      label: label,
      controller: controller,
      options: _dropdownOptions?.scheduledWeekly ?? [],
      icon: Icons.calendar_today,
    );
  }

  /// 汎用ドロップダウンを生成
  Widget _buildDropdown({
    required String label,
    required TextEditingController controller,
    required List<String> options,
    required IconData icon,
    String? hintText,
  }) {
    // ドロップダウン選択肢がまだ読み込まれていない場合
    if (_isLoadingDropdowns) {
      return TextFormField(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: Icon(icon),
          hintText: '読み込み中...',
          floatingLabelBehavior: FloatingLabelBehavior.always,
        ),
        enabled: false,
      );
    }

    // ドロップダウン選択肢がない、または空の場合は通常の入力欄
    if (options.isEmpty) {
      return TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: Icon(icon),
          hintText: hintText,
          floatingLabelBehavior: FloatingLabelBehavior.always,
        ),
        enabled: !_isLoading,
      );
    }

    // ドロップダウン選択肢がある場合はドロップダウン
    final currentValue = controller.text.trim();

    return DropdownButtonFormField<String>(
      value: options.contains(currentValue) ? currentValue : null,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
        floatingLabelBehavior: FloatingLabelBehavior.always,
      ),
      items: [
        // 空の選択肢
        const DropdownMenuItem<String>(
          value: '',
          child: Text('（未選択）'),
        ),
        // マスタ設定からの選択肢
        ...options.map((option) {
          return DropdownMenuItem<String>(
            value: option,
            child: Text(option),
          );
        }),
      ],
      onChanged: _isLoading
          ? null
          : (value) {
              setState(() {
                controller.text = value ?? '';
              });
            },
    );
  }

  /// 加算項目用のラジオボタングループを生成
  Widget _buildSubsidyRadioGroup({
    required String label,
    required String value,
    required void Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            children: [
              RadioListTile<String>(
                title: const Text('加算を算定する'),
                value: '○',
                groupValue: value,
                onChanged: _isLoading ? null : (val) => onChanged(val ?? ''),
                dense: true,
              ),
              const Divider(height: 1),
              RadioListTile<String>(
                title: const Text('加算を算定しない'),
                value: '',
                groupValue: value,
                onChanged: _isLoading ? null : (val) => onChanged(val ?? ''),
                dense: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
