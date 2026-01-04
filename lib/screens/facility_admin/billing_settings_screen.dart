import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/billing_service.dart';

/// 請求業務設定画面
class BillingSettingsScreen extends StatefulWidget {
  final String? gasUrl;
  final String? facilityId;

  const BillingSettingsScreen({
    super.key,
    this.gasUrl,
    this.facilityId,
  });

  @override
  State<BillingSettingsScreen> createState() => _BillingSettingsScreenState();
}

class _BillingSettingsScreenState extends State<BillingSettingsScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late BillingService _billingService;
  late TabController _tabController;
  bool _isLoading = true;
  bool _isSaving = false;

  // === 必須テキスト項目 ===
  final _corporateNameController = TextEditingController(); // 法人名
  final _representativeController = TextEditingController(); // 代表者
  final _businessNameController = TextEditingController(); // 事業者名
  final _abbreviationController = TextEditingController(); // 略称
  final _managerController = TextEditingController(); // 管理者
  final _businessNumberController = TextEditingController(); // 事業者番号
  final _postalCodeController = TextEditingController(); // 郵便番号
  final _addressController = TextEditingController(); // 住所
  final _phoneController = TextEditingController(); // 電話番号
  final _invoicePositionController = TextEditingController(); // 請求書役職
  final _invoiceNameController = TextEditingController(); // 請求書氏名

  // === 非必須テキスト項目 ===
  final _serviceYearMonthController = TextEditingController(); // サービス提供年月
  final _capacityController = TextEditingController(); // 定員
  final _typeCapacityController = TextEditingController(); // 種類別定員
  final _standardUnitController = TextEditingController(); // 基準該当算定単位数
  final _transitionWorkersController = TextEditingController(); // 就労移行支援体制加算（就労定着者数）
  final _overCapacityController = TextEditingController(); // 定員超過
  final _invoiceNoteController = TextEditingController(); // 利用者請求書備考
  final _expense1Controller = TextEditingController(); // 実費１
  final _expense2Controller = TextEditingController(); // 実費２

  // === プルダウン項目 ===
  String? _selectedType; // 種別
  String? _selectedWageCategory; // 平均工賃月額区分
  String? _selectedRegionCategory; // 地域区分（必須）
  String? _selectedWelfareStaffAddition; // 福祉専門職員配置等加算
  String? _selectedTransportAddition; // 送迎加算種類
  String? _selectedVisualHearingSpeechSupport; // 視覚聴覚言語障害者支援体制加算

  // === コンボボックス項目（プルダウン＋手入力） ===
  final _employeeShortageController = TextEditingController(); // 従業員欠員
  final _serviceManagerShortageController = TextEditingController(); // サービス管理責任者欠員
  final _severeSupportController = TextEditingController(); // 重度者支援体制加算
  final _targetWageInstructorController = TextEditingController(); // 目標工賃達成指導員配置加算（数字入力）
  final _severeSupport2Controller = TextEditingController(); // 重度者支援体制加算２
  final _medicalCooperationController = TextEditingController(); // 医療連携看護職員（数字入力）
  String? _selectedWelfareImprovement; // 福祉介護職員等処遇改善加算

  // === チェックボックス項目 ===
  bool _isPublic = false; // 公立
  bool _hasTransitionSupport = false; // 就労移行支援体制加算
  bool _hasTargetWageAchievement = false; // 目標工賃達成加算
  bool _hasRestraintReduction = false; // 身体拘束廃止未実施減算
  bool _hasRegionalLifeSupport = false; // 地域生活支援拠点等
  bool _hasShortTimeReduction = false; // 短時間利用減算
  bool _hasInfoDisclosureReduction = false; // 情報公表未報告減算
  bool _hasBcpReduction = false; // 業務継続計画未策定減算
  bool _hasAbusePreventionReduction = false; // 虐待防止措置未実施減算
  bool _hasHigherBrainSupport = false; // 高次脳機能障害者支援体制加算
  bool _isDesignatedFacility = false; // 指定障害者支援施設

  // === プルダウン選択肢（マスタ設定シート K61〜P90から動的取得） ===
  List<String> _typeOptions = []; // K列：種別
  List<String> _wageCategoryOptions = []; // L列：平均工賃月額区分
  List<String> _regionCategoryOptions = []; // M列：地域区分
  List<String> _welfareStaffAdditionOptions = []; // N列：福祉専門職員配置等加算
  List<String> _transportAdditionOptions = []; // O列：送迎加算種類
  List<String> _welfareImprovementOptions = []; // P列：福祉介護職員等処遇改善加算
  // その他のプルダウン（アプリ側で定義）
  final List<String> _visualHearingSpeechSupportOptions = ['なし', 'I', 'II'];
  // コンボボックス選択肢（空欄、○、●、または数字手入力）
  // Unicode: ○ = U+25CB (WHITE CIRCLE), ● = U+25CF (BLACK CIRCLE)
  final List<String> _shortageOptions = ['', '\u25CB', '\u25CF'];
  // 定員超過用選択肢（空欄、○、または数字手入力）
  final List<String> _overCapacityOptions = ['', '\u25CB'];

  // === 市町村情報 ===
  final _municipalityNameController = TextEditingController(); // 市町村名
  final _municipalityCodeController = TextEditingController(); // 市町村番号
  List<Map<String, String>> _municipalities = []; // 登録済み市町村リスト
  bool _isMunicipalityLoading = false;
  bool _isMunicipalitySaving = false;

  // === 利用者選択 ===
  DateTime _selectedServiceMonth = DateTime.now(); // 選択中のサービス提供年月
  List<MonthlyUser> _users = []; // 選択月の利用者一覧
  Set<String> _selectedUsers = {}; // 選択された利用者名
  bool _isUsersLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _billingService = BillingService(facilityGasUrl: widget.gasUrl);
    _loadDropdowns();
    _loadMunicipalities(); // 市町村一覧も初期読み込み
    _loadUsersForMonth(_selectedServiceMonth); // 現在月の利用者を初期読み込み
  }

  /// プルダウン選択肢と既存設定を取得
  Future<void> _loadDropdowns() async {
    setState(() => _isLoading = true);

    try {
      // プルダウン選択肢と既存設定を並行取得
      final results = await Future.wait([
        _billingService.getBillingDropdowns(),
        _billingService.getBillingSettings(),
      ]);

      final dropdowns = results[0] as BillingDropdowns;
      final settings = results[1] as Map<String, dynamic>;

      setState(() {
        // プルダウン選択肢
        _typeOptions = dropdowns.type;
        _wageCategoryOptions = dropdowns.wageCategory;
        _regionCategoryOptions = dropdowns.regionCategory;
        _welfareStaffAdditionOptions = dropdowns.welfareStaffAddition;
        _transportAdditionOptions = dropdowns.transportAddition;
        _welfareImprovementOptions = dropdowns.welfareImprovement;

        // 既存設定を反映
        _applySettings(settings);

        _isLoading = false;
      });
    } catch (e) {
      // エラー時はデフォルト値を使用
      final defaults = BillingDropdowns.defaultValues();
      setState(() {
        _typeOptions = defaults.type;
        _wageCategoryOptions = defaults.wageCategory;
        _regionCategoryOptions = defaults.regionCategory;
        _welfareStaffAdditionOptions = defaults.welfareStaffAddition;
        _transportAdditionOptions = defaults.transportAddition;
        _welfareImprovementOptions = defaults.welfareImprovement;
        _isLoading = false;
      });
    }
  }

  /// 既存設定をフォームに反映
  void _applySettings(Map<String, dynamic> settings) {
    if (settings.isEmpty) return;

    // テキストフィールド
    _serviceYearMonthController.text = _parseString(settings['serviceYearMonth']);
    _corporateNameController.text = _parseString(settings['corporateName']);
    _representativeController.text = _parseString(settings['representative']);
    _businessNameController.text = _parseString(settings['businessName']);
    _abbreviationController.text = _parseString(settings['abbreviation']);
    _managerController.text = _parseString(settings['manager']);
    _businessNumberController.text = _parseString(settings['businessNumber']);
    _postalCodeController.text = _parseString(settings['postalCode']);
    _addressController.text = _parseString(settings['address']);
    _phoneController.text = _parseString(settings['phone']);
    _capacityController.text = _parseString(settings['capacity']);
    _typeCapacityController.text = _parseString(settings['typeCapacity']);
    _standardUnitController.text = _parseString(settings['standardUnit']);
    _transitionWorkersController.text = _parseString(settings['transitionWorkers']);
    _invoicePositionController.text = _parseString(settings['invoicePosition']);
    _invoiceNameController.text = _parseString(settings['invoiceName']);
    _invoiceNoteController.text = _parseString(settings['invoiceNote']);
    _expense1Controller.text = _parseString(settings['expense1']);
    _expense2Controller.text = _parseString(settings['expense2']);

    // コンボボックス
    _overCapacityController.text = _parseString(settings['overCapacity']);
    _employeeShortageController.text = _parseString(settings['employeeShortage']);
    _serviceManagerShortageController.text = _parseString(settings['serviceManagerShortage']);
    _severeSupportController.text = _parseString(settings['severeSupport']);
    _targetWageInstructorController.text = _parseString(settings['targetWageInstructor']);
    _severeSupport2Controller.text = _parseString(settings['severeSupport2']);
    _medicalCooperationController.text = _parseString(settings['medicalCooperation']);

    // プルダウン
    _selectedType = _nullIfEmpty(settings['type']);
    _selectedWageCategory = _nullIfEmpty(settings['wageCategory']);
    _selectedRegionCategory = _nullIfEmpty(settings['regionCategory']);
    _selectedWelfareStaffAddition = _nullIfEmpty(settings['welfareStaffAddition']);
    _selectedTransportAddition = _nullIfEmpty(settings['transportAddition']);
    _selectedVisualHearingSpeechSupport = _nullIfEmpty(settings['visualHearingSpeechSupport']);
    _selectedWelfareImprovement = _nullIfEmpty(settings['welfareImprovement']);

    // チェックボックス（true または「○」ならtrue）
    _isPublic = _parseBool(settings['isPublic']);
    _hasTransitionSupport = _parseBool(settings['hasTransitionSupport']);
    _hasTargetWageAchievement = _parseBool(settings['hasTargetWageAchievement']);
    _hasRestraintReduction = _parseBool(settings['hasRestraintReduction']);
    _hasRegionalLifeSupport = _parseBool(settings['hasRegionalLifeSupport']);
    _hasShortTimeReduction = _parseBool(settings['hasShortTimeReduction']);
    _hasInfoDisclosureReduction = _parseBool(settings['hasInfoDisclosureReduction']);
    _hasBcpReduction = _parseBool(settings['hasBcpReduction']);
    _hasAbusePreventionReduction = _parseBool(settings['hasAbusePreventionReduction']);
    _hasHigherBrainSupport = _parseBool(settings['hasHigherBrainSupport']);
    _isDesignatedFacility = _parseBool(settings['isDesignatedFacility']);
  }

  String _parseString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  String? _nullIfEmpty(dynamic value) {
    if (value == null) return null;
    final str = value is String ? value : value.toString();
    if (str.isEmpty) return null;
    return str;
  }

  bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    // Unicode: ○ = U+25CB (WHITE CIRCLE)
    if (value is String) return value == '\u25CB' || value == '○' || value.toLowerCase() == 'true';
    return false;
  }

  @override
  void dispose() {
    _tabController.dispose();
    // 必須テキスト
    _corporateNameController.dispose();
    _representativeController.dispose();
    _businessNameController.dispose();
    _abbreviationController.dispose();
    _managerController.dispose();
    _businessNumberController.dispose();
    _postalCodeController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _invoicePositionController.dispose();
    _invoiceNameController.dispose();
    // 非必須テキスト
    _serviceYearMonthController.dispose();
    _capacityController.dispose();
    _typeCapacityController.dispose();
    _standardUnitController.dispose();
    _transitionWorkersController.dispose();
    _overCapacityController.dispose();
    // コンボボックス
    _employeeShortageController.dispose();
    _serviceManagerShortageController.dispose();
    _severeSupportController.dispose();
    _targetWageInstructorController.dispose();
    _severeSupport2Controller.dispose();
    _medicalCooperationController.dispose();
    _invoiceNoteController.dispose();
    _expense1Controller.dispose();
    _expense2Controller.dispose();
    // 市町村情報
    _municipalityNameController.dispose();
    _municipalityCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('請求業務設定'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveSettings,
              tooltip: '保存',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: '施設情報', icon: Icon(Icons.business)),
            Tab(text: '市町村情報', icon: Icon(Icons.location_city)),
            Tab(text: '設定・実行', icon: Icon(Icons.play_circle)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFacilityInfoTab(),
                  _buildMunicipalityInfoTab(),
                  _buildSettingsExecuteTab(),
                ],
              ),
            ),
    );
  }

  /// 施設情報タブ
  Widget _buildFacilityInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 基本情報セクション
          _buildSectionHeader('基本情報', Icons.business, Colors.teal),
                    const SizedBox(height: 12),
                    _buildRequiredTextField(
                      controller: _corporateNameController,
                      label: '法人名',
                    ),
                    _buildRequiredTextField(
                      controller: _representativeController,
                      label: '代表者',
                    ),
                    _buildRequiredTextField(
                      controller: _businessNameController,
                      label: '事業者名',
                    ),
                    _buildRequiredTextField(
                      controller: _abbreviationController,
                      label: '略称',
                    ),
                    _buildRequiredTextField(
                      controller: _managerController,
                      label: '管理者',
                    ),
                    _buildRequiredTextField(
                      controller: _businessNumberController,
                      label: '事業者番号',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 24),

                    // 所在地情報セクション
                    _buildSectionHeader('所在地情報', Icons.location_on, Colors.blue),
                    const SizedBox(height: 12),
                    _buildRequiredTextField(
                      controller: _postalCodeController,
                      label: '郵便番号',
                      hint: '例: 123-4567',
                    ),
                    _buildRequiredTextField(
                      controller: _addressController,
                      label: '住所',
                    ),
                    _buildRequiredTextField(
                      controller: _phoneController,
                      label: '電話番号',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 24),

                    // 事業所区分セクション
                    _buildSectionHeader('事業所区分', Icons.category, Colors.purple),
                    const SizedBox(height: 12),
                    _buildDropdown(
                      label: '種別',
                      value: _selectedType,
                      options: _typeOptions,
                      onChanged: (v) => setState(() => _selectedType = v),
                      tooltip: '''次のいずれかを選択

就労継続支援Ｂ型サービス費（Ⅰ）(6:1)　→　就継ＢⅠ
就労継続支援Ｂ型サービス費（Ⅱ）(7.5:1)　→　就継ＢⅡ
就労継続支援Ｂ型サービス費（Ⅲ）(10:1)　→　就継ＢⅢ
就労継続支援Ｂ型サービス費（Ⅳ）(6:1)　→　就継ＢⅣ
就労継続支援Ｂ型サービス費（Ⅴ）(7.5:1)　→　就継ＢⅤ
就労継続支援Ｂ型サービス費（Ⅵ）(10:1)　→　就継ＢⅥ
基準該当就労継続支援Ｂ型サービス費　→　基準該当就継Ｂ''',
                    ),
                    _buildDropdown(
                      label: '平均工賃月額区分',
                      value: _selectedWageCategory,
                      options: _wageCategoryOptions,
                      onChanged: (v) => setState(() => _selectedWageCategory = v),
                      tooltip: '''就継ＢⅠ、就継ＢⅡ、就継ＢⅢ
平均工賃月額が４万５千円以上 → 1
平均工賃月額が３万円５千以上４万５千円未満 → 2
平均工賃月額が３万円以上３万５千円未満 → 3
平均工賃月額が２万５千円以上３万円未満 → 4
平均工賃月額が２万円以上２万５千円未満 → 5
平均工賃月額が１万５千円以上２万円未満 → 6
平均工賃月額が１万円以上１万５千円未満 → 7
なし（経過措置）→ 8
平均工賃月額が１万円未満 → 9

就継ＢⅣ、就継ＢⅤ、就継ＢⅥ
設定しない→ 10''',
                    ),
                    _buildCheckbox(
                      label: '公立',
                      value: _isPublic,
                      onChanged: (v) => setState(() => _isPublic = v ?? false),
                      tooltip: '''民改費加算の対象となっていない公立施設
公立　→　○
私立　→　何も入力しない''',
                    ),
                    _buildDropdown(
                      label: '地域区分',
                      value: _selectedRegionCategory,
                      options: _regionCategoryOptions,
                      onChanged: (v) => setState(() => _selectedRegionCategory = v),
                      isRequired: true,
                    ),
                    _buildRequiredTextField(
                      controller: _capacityController,
                      label: '定員',
                      keyboardType: TextInputType.number,
                      isRequired: false,
                      tooltip: '''定員数を入力してください。
※多機能型の場合、合計の人数を入れてください。''',
                    ),
                    _buildRequiredTextField(
                      controller: _typeCapacityController,
                      label: '種類別定員',
                      isRequired: false,
                      tooltip: '''多機能型の場合、当該サービス種類の定員を入れてください。''',
                    ),
                    _buildRequiredTextField(
                      controller: _standardUnitController,
                      label: '基準該当算定単位数',
                      keyboardType: TextInputType.number,
                      isRequired: false,
                      tooltip: '''基準該当の場合基本の単位数を入力する''',
                    ),
                    const SizedBox(height: 24),

                    // 加算項目セクション
                    _buildSectionHeader('加算項目', Icons.add_circle, Colors.green),
                    const SizedBox(height: 12),
                    _buildCheckbox(
                      label: '就労移行支援体制加算',
                      value: _hasTransitionSupport,
                      onChanged: (v) => setState(() => _hasTransitionSupport = v ?? false),
                    ),
                    if (_hasTransitionSupport)
                      Padding(
                        padding: const EdgeInsets.only(left: 32.0),
                        child: _buildRequiredTextField(
                          controller: _transitionWorkersController,
                          label: '就労定着者数',
                          keyboardType: TextInputType.number,
                          isRequired: false,
                          tooltip: '''就労移行支援体制加算を請求する場合に前年度定着者数を入力する
4人　→　4''',
                        ),
                      ),
                    _buildDropdown(
                      label: '福祉専門職員配置等加算',
                      value: _selectedWelfareStaffAddition,
                      options: _welfareStaffAdditionOptions,
                      onChanged: (v) => setState(() => _selectedWelfareStaffAddition = v),
                      tooltip: '''福祉専門職員配置等加算を請求する
福祉専門職員配置等加算Ⅰ　→　10
福祉専門職員配置等加算Ⅱ　→　20
福祉専門職員配置等加算Ⅲ　→　30
請求しない　→　何も入力しない''',
                    ),
                    _buildComboField(
                      controller: _severeSupportController,
                      label: '重度者支援体制加算',
                      options: _overCapacityOptions,
                      hint: '空欄/○または数字入力',
                      tooltip: '''重度者支援体制加算Ⅰを請求する
なし → 何も入力しない
全部 → ○
10日と15日だけ　→ 10,15　（該当日をカンマで区切る）
※多機能型の場合は、就労継続B型だけの定員を入力します。''',
                    ),
                    _buildComboField(
                      controller: _targetWageInstructorController,
                      label: '目標工賃達成指導員配置加算',
                      options: _overCapacityOptions,
                      hint: '空欄/○または数字入力',
                      tooltip: '''目標工賃達成指導員配置加算を請求する
全部 → ○
請求する場合は人数を入力
請求しない　→　何も入力しない
※多機能型の場合は、就労継続B型だけの定員を入力します。''',
                    ),
                    _buildCheckbox(
                      label: '目標工賃達成加算',
                      value: _hasTargetWageAchievement,
                      onChanged: (v) => setState(() => _hasTargetWageAchievement = v ?? false),
                      tooltip: '''目標工賃達成加算を請求する
請求する　→　○
請求しない　→　何も入力しない
※多機能型の場合は、就労継続B型だけの定員を入力します。''',
                    ),
                    _buildComboField(
                      controller: _severeSupport2Controller,
                      label: '重度者支援体制加算２',
                      options: _overCapacityOptions,
                      hint: '空欄/○または数字入力',
                      tooltip: '''重度者支援体制加算Ⅱを請求する
なし → 何も入力しない
全部 → ○
10日と15日だけ　→ 10,15　（該当日をカンマで区切る）
※多機能型の場合は、就労継続B型だけの定員を入力します。''',
                    ),
                    _buildRequiredTextField(
                      controller: _medicalCooperationController,
                      label: '医療連携看護職員',
                      keyboardType: TextInputType.number,
                      isRequired: false,
                      hint: '看護職員数を入力',
                      tooltip: '''医療連携体制加算Ⅴを算定する場合の看護職員数''',
                    ),
                    _buildDropdown(
                      label: '送迎加算種類',
                      value: _selectedTransportAddition,
                      options: _transportAdditionOptions,
                      onChanged: (v) => setState(() => _selectedTransportAddition = v),
                      tooltip: '''送迎加算を請求する
送迎加算Ⅰ　→　1 , 空白
送迎加算Ⅱ　→　21''',
                    ),
                    _buildCheckbox(
                      label: '地域生活支援拠点等',
                      value: _hasRegionalLifeSupport,
                      onChanged: (v) => setState(() => _hasRegionalLifeSupport = v ?? false),
                      tooltip: '''地域生活支援拠点等を担う
担う → ○
担わない → 入力しない''',
                    ),
                    _buildCheckbox(
                      label: '高次脳機能障害者支援体制加算',
                      value: _hasHigherBrainSupport,
                      onChanged: (v) => setState(() => _hasHigherBrainSupport = v ?? false),
                      tooltip: '''高次脳機能障害者支援体制加算を請求する
請求する　→　○
請求しない　→　何も入力しない''',
                    ),
                    _buildDropdown(
                      label: '視覚聴覚言語障害者支援体制加算',
                      value: _selectedVisualHearingSpeechSupport,
                      options: _visualHearingSpeechSupportOptions,
                      onChanged: (v) => setState(() => _selectedVisualHearingSpeechSupport = v),
                      tooltip: '''視覚・聴覚言語障害者支援体制加算を請求する
視覚・聴覚言語障害者支援体制加算Ⅰ　→　1
視覚・聴覚言語障害者支援体制加算Ⅱ　→　2''',
                    ),
                    const SizedBox(height: 24),

                    // 減算項目セクション
                    _buildSectionHeader('減算項目', Icons.remove_circle, Colors.red),
                    const SizedBox(height: 12),
                    _buildCheckbox(
                      label: '身体拘束廃止未実施減算',
                      value: _hasRestraintReduction,
                      onChanged: (v) => setState(() => _hasRestraintReduction = v ?? false),
                      tooltip: '''身体拘束廃止未実施減算を請求する
請求する　→　○
請求しない　→　何も入力しない''',
                    ),
                    _buildComboField(
                      controller: _overCapacityController,
                      label: '定員超過',
                      options: _overCapacityOptions,
                      hint: '空欄/○または数字入力',
                      tooltip: '''定員を超過した日
なし → 何も入力しない
全部 → ○
10日と15日だけ　→ 10,15　（該当日をカンマで区切る）''',
                    ),
                    _buildComboField(
                      controller: _employeeShortageController,
                      label: '従業員欠員',
                      options: _shortageOptions,
                      hint: '空欄/○/●または数字入力',
                      tooltip: '''従業員が欠員した日
なし → 何も入力しない

提供月すべての日に減算
２か月目まで → ○
３か月目から → ●

日ごとに減算
10日と15日だけ　→ 10,15　（該当日をカンマで区切る）
※２か月目までと同じ減算''',
                    ),
                    _buildComboField(
                      controller: _serviceManagerShortageController,
                      label: 'サービス管理責任者欠員',
                      options: _shortageOptions,
                      hint: '空欄/○/●または数字入力',
                      tooltip: '''サービス管理責任者が欠員した日
なし → 何も入力しない

提供月すべての日に減算
４か月目まで → ○
５か月目から → ●

日ごとに減算
10日と15日だけ　→ 10,15　（該当日をカンマで区切る）
※４か月目までと同じ減算''',
                    ),
                    _buildCheckbox(
                      label: '短時間利用減算',
                      value: _hasShortTimeReduction,
                      onChanged: (v) => setState(() => _hasShortTimeReduction = v ?? false),
                      tooltip: '''短時間利用減算を請求する
請求する　→　○
請求しない　→　何も入力しない''',
                    ),
                    _buildCheckbox(
                      label: '情報公表未報告減算',
                      value: _hasInfoDisclosureReduction,
                      onChanged: (v) => setState(() => _hasInfoDisclosureReduction = v ?? false),
                      tooltip: '''情報公表未報告減算を請求する
請求する　→　○
請求しない　→　何も入力しない''',
                    ),
                    _buildCheckbox(
                      label: '業務継続計画未策定減算',
                      value: _hasBcpReduction,
                      onChanged: (v) => setState(() => _hasBcpReduction = v ?? false),
                      tooltip: '''業務継続計画未策定減算を請求する
請求する　→　○
請求しない　→　何も入力しない''',
                    ),
                    _buildCheckbox(
                      label: '虐待防止措置未実施減算',
                      value: _hasAbusePreventionReduction,
                      onChanged: (v) => setState(() => _hasAbusePreventionReduction = v ?? false),
                      tooltip: '''虐待防止措置未実施減算を請求する
請求する　→　○
請求しない　→　何も入力しない''',
                    ),
                    const SizedBox(height: 24),

                    // 処遇改善セクション（入力不可）
                    _buildSectionHeader('処遇改善（自動計算）', Icons.lock, Colors.grey),
                    const SizedBox(height: 12),
                    _buildDisabledField(label: '処遇改善都道府県'),
                    _buildDisabledField(label: '処遇改善都道府県番号'),
                    _buildDisabledField(label: '処遇改善キャリアパス区分'),
                    _buildDisabledField(label: '特定処遇改善加算'),
                    _buildDisabledField(label: 'ベースアップ等支援加算'),
                    _buildDropdown(
                      label: '福祉介護職員等処遇改善加算',
                      value: _selectedWelfareImprovement,
                      options: _welfareImprovementOptions,
                      onChanged: (v) => setState(() => _selectedWelfareImprovement = v),
                      tooltip: '''福祉・介護職員等処遇改善加算を請求する

福祉・介護職員等処遇改善加算Ⅰ　→　1
福祉・介護職員等処遇改善加算Ⅱ　→　2
福祉・介護職員等処遇改善加算Ⅲ　→　3
福祉・介護職員等処遇改善加算Ⅳ　→　4
福祉・介護職員等処遇改善加算Ⅴ(1)　→　51
福祉・介護職員等処遇改善加算Ⅴ(2)　→　52
福祉・介護職員等処遇改善加算Ⅴ(3)　→　53
福祉・介護職員等処遇改善加算Ⅴ(4)　→　54
福祉・介護職員等処遇改善加算Ⅴ(5)　→　55
福祉・介護職員等処遇改善加算Ⅴ(6)　→　56
福祉・介護職員等処遇改善加算Ⅴ(7)　→　57
福祉・介護職員等処遇改善加算Ⅴ(8)　→　58
福祉・介護職員等処遇改善加算Ⅴ(9) 　→　59
福祉・介護職員等処遇改善加算Ⅴ(10)　→　510
福祉・介護職員等処遇改善加算Ⅴ(11)　→　511
福祉・介護職員等処遇改善加算Ⅴ(12)　→　512
福祉・介護職員等処遇改善加算Ⅴ(13)　→　513
福祉・介護職員等処遇改善加算Ⅴ(14)　→　514
請求しない　→　何も入力しない''',
                    ),
                    const SizedBox(height: 24),

                    // その他セクション
                    _buildSectionHeader('その他', Icons.more_horiz, Colors.orange),
                    const SizedBox(height: 12),
                    _buildCheckbox(
                      label: '指定障害者支援施設',
                      value: _isDesignatedFacility,
                      onChanged: (v) => setState(() => _isDesignatedFacility = v ?? false),
                      tooltip: '''指定障害者支援施設
該当する → ○
該当しない → 何も入力しない''',
                    ),
                    const SizedBox(height: 24),

                    // 請求書情報セクション
                    _buildSectionHeader('請求書情報', Icons.receipt_long, Colors.indigo),
                    const SizedBox(height: 12),
                    _buildRequiredTextField(
                      controller: _invoicePositionController,
                      label: '請求書役職',
                    ),
                    _buildRequiredTextField(
                      controller: _invoiceNameController,
                      label: '請求書氏名',
                    ),
                    _buildRequiredTextField(
                      controller: _invoiceNoteController,
                      label: '利用者請求書備考',
                      isRequired: false,
                      maxLines: 3,
                    ),
                    _buildRequiredTextField(
                      controller: _expense1Controller,
                      label: '実費１',
                      isRequired: false,
                      tooltip: '''ex)おやつ代など''',
                    ),
                    _buildRequiredTextField(
                      controller: _expense2Controller,
                      label: '実費２',
                      isRequired: false,
                    ),
          const SizedBox(height: 32),

          // 保存ボタン
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveSettings,
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save),
            label: Text(_isSaving ? '保存中...' : '設定を保存'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// 市町村情報タブ
  Widget _buildMunicipalityInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 市町村登録セクション
          _buildSectionHeader('市町村を登録', Icons.add_location, Colors.indigo),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _municipalityNameController,
                    decoration: const InputDecoration(
                      labelText: '市町村名',
                      hintText: '例: 渋谷区',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_city),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _municipalityCodeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '市町村番号',
                      hintText: '例: 131130',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.numbers),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _isMunicipalitySaving ? null : _addMunicipality,
                    icon: _isMunicipalitySaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add),
                    label: Text(_isMunicipalitySaving ? '登録中...' : '市町村を追加'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 登録済み市町村一覧セクション
          _buildSectionHeader('登録済み市町村一覧', Icons.list, Colors.teal),
          const SizedBox(height: 12),

          if (_isMunicipalityLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_municipalities.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    Icon(Icons.info_outline, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      '登録された市町村はありません',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _municipalities.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final municipality = _municipalities[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.indigo.shade100,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: Colors.indigo.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      municipality['name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('市町村番号: ${municipality['code'] ?? ''}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _deleteMunicipality(index),
                      tooltip: '削除',
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 16),

          // 更新ボタン
          OutlinedButton.icon(
            onPressed: _isMunicipalityLoading ? null : _loadMunicipalities,
            icon: const Icon(Icons.refresh),
            label: const Text('一覧を更新'),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// 市町村を追加
  Future<void> _addMunicipality() async {
    final name = _municipalityNameController.text.trim();
    final code = _municipalityCodeController.text.trim();

    if (name.isEmpty || code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('市町村名と市町村番号を入力してください'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isMunicipalitySaving = true);

    try {
      await _billingService.addMunicipality(name, code);

      // 入力フィールドをクリア
      _municipalityNameController.clear();
      _municipalityCodeController.clear();

      // 一覧を再読み込み
      await _loadMunicipalities();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('市町村を追加しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('追加エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isMunicipalitySaving = false);
      }
    }
  }

  /// 市町村を削除
  Future<void> _deleteMunicipality(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認'),
        content: Text('「${_municipalities[index]['name']}」を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isMunicipalityLoading = true);

    try {
      await _billingService.deleteMunicipality(index);
      await _loadMunicipalities();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('市町村を削除しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('削除エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isMunicipalityLoading = false);
      }
    }
  }

  /// 市町村一覧を読み込み
  Future<void> _loadMunicipalities() async {
    setState(() => _isMunicipalityLoading = true);

    try {
      final municipalities = await _billingService.getMunicipalities();
      setState(() {
        _municipalities = municipalities;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('読み込みエラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isMunicipalityLoading = false);
      }
    }
  }

  /// 設定・実行タブ
  Widget _buildSettingsExecuteTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader('設定・実行', Icons.play_circle, Colors.orange),
          const SizedBox(height: 12),

          // サービス提供年月セレクター
          _buildServiceMonthSelector(),

          const SizedBox(height: 24),

          // 利用者選択セクション
          _buildUserSelectionSection(),

          const SizedBox(height: 24),

          // 実行ボタン
          _buildExecuteButton(),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  bool _isExecuting = false;

  /// 実行ボタン
  Widget _buildExecuteButton() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.send, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Text(
                  '請求データ出力',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '選択した${_selectedUsers.length}名の利用者情報を請求シートに出力します。',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _selectedUsers.isEmpty || _isExecuting
                  ? null
                  : _executeBilling,
              icon: _isExecuting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(_isExecuting ? '出力中...' : '実行'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 請求データ出力を実行
  Future<void> _executeBilling() async {
    if (_selectedUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('利用者を選択してください')),
      );
      return;
    }

    setState(() => _isExecuting = true);

    try {
      final yearMonth =
          '${_selectedServiceMonth.year}-${_selectedServiceMonth.month.toString().padLeft(2, '0')}';
      // 名簿シートの並び順を保持するため、_usersからフィルタリング
      final orderedUsers = _users
          .where((u) => _selectedUsers.contains(u.name))
          .map((u) => u.name)
          .toList();
      final result = await _billingService.executeBilling(
        users: orderedUsers,
        yearMonth: yearMonth,
      );

      if (mounted) {
        // デバッグログ
        print('🔍 result keys: ${result.keys.toList()}');
        print('🔍 xlsxBase64 is null: ${result['xlsxBase64'] == null}');
        print('🔍 xlsxBase64 length: ${(result['xlsxBase64'] as String?)?.length ?? 0}');
        print('🔍 xlsxError: ${result['xlsxError']}');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? '出力完了'),
            backgroundColor: Colors.green,
          ),
        );

        // xlsxファイルをダウンロードするか確認
        final xlsxBase64 = result['xlsxBase64'] as String?;
        final xlsxError = result['xlsxError'] as String?;
        if (xlsxBase64 != null && xlsxBase64.isNotEmpty) {
          print('✅ xlsxBase64 received, showing dialog');
          _showDownloadDialog(xlsxBase64, yearMonth);
        } else {
          print('❌ xlsxBase64 is null or empty, error: $xlsxError');
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
        setState(() => _isExecuting = false);
      }
    }
  }

  /// xlsxダウンロード確認ダイアログを表示
  void _showDownloadDialog(String xlsxBase64, String yearMonth) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.download, color: Colors.blue),
            SizedBox(width: 8),
            Text('Excelダウンロード'),
          ],
        ),
        content: const Text('請求データをExcelファイルとしてダウンロードしますか？\n\n※スプレッドシートの書式がそのまま保持されます'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _saveExcelFile(xlsxBase64, yearMonth);
            },
            icon: const Icon(Icons.download),
            label: const Text('ダウンロード'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Base64データからExcelファイルを保存
  Future<void> _saveExcelFile(String xlsxBase64, String yearMonth) async {
    try {
      // Base64をデコード
      final bytes = base64Decode(xlsxBase64);

      // ファイル名
      final fileName = '請求データ_$yearMonth.xlsx';
      String filePath;
      final isDesktop = Platform.isMacOS || Platform.isWindows;

      if (isDesktop) {
        // Windows/macOS: ダウンロードフォルダに保存
        final downloadsDir = await getDownloadsDirectory();
        if (downloadsDir != null) {
          filePath = '${downloadsDir.path}/$fileName';
        } else {
          final tempDir = await getTemporaryDirectory();
          filePath = '${tempDir.path}/$fileName';
        }
      } else {
        // iOS/Android: 一時フォルダに保存
        final tempDir = await getTemporaryDirectory();
        filePath = '${tempDir.path}/$fileName';
      }

      // ファイル保存
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ダウンロードフォルダに保存しました: $fileName'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel保存エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// サービス提供年月セレクター
  Widget _buildServiceMonthSelector() {
    final now = DateTime.now();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_month, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                Text(
                  'サービス提供年月',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 前月ボタン
                IconButton(
                  onPressed: () => _changeServiceMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                  iconSize: 32,
                ),
                // 年月表示（タップで日付ピッカー）
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedServiceMonth,
                      firstDate: DateTime(2024, 1),
                      lastDate: now,
                      initialDatePickerMode: DatePickerMode.year,
                      locale: const Locale('ja'),
                    );
                    if (picked != null) {
                      _changeServiceMonthTo(DateTime(picked.year, picked.month, 1));
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Text(
                      '${_selectedServiceMonth.year}年${_selectedServiceMonth.month}月',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
                ),
                // 次月ボタン
                IconButton(
                  onPressed: _selectedServiceMonth.year == now.year &&
                          _selectedServiceMonth.month == now.month
                      ? null
                      : () => _changeServiceMonth(1),
                  icon: const Icon(Icons.chevron_right),
                  iconSize: 32,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// サービス提供年月を変更（前後月）
  void _changeServiceMonth(int delta) {
    final newMonth = DateTime(
      _selectedServiceMonth.year,
      _selectedServiceMonth.month + delta,
      1,
    );
    _changeServiceMonthTo(newMonth);
  }

  /// サービス提供年月を指定月に変更
  void _changeServiceMonthTo(DateTime newMonth) {
    setState(() {
      _selectedServiceMonth = newMonth;
      // サービス提供年月のテキストフィールドも更新
      _serviceYearMonthController.text =
          '${newMonth.year}${newMonth.month.toString().padLeft(2, '0')}';
    });
    // 選択した月の利用者を再取得
    _loadUsersForMonth(newMonth);
  }

  /// 指定月の利用者を読み込み
  Future<void> _loadUsersForMonth(DateTime month) async {
    setState(() => _isUsersLoading = true);

    try {
      final yearMonth = '${month.year}-${month.month.toString().padLeft(2, '0')}';
      final users = await _billingService.getMonthlyUsers(yearMonth);
      if (mounted) {
        setState(() {
          _users = users;
          // 全員を選択状態に
          _selectedUsers = users.map((u) => u.name).toSet();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('利用者読み込みエラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUsersLoading = false);
      }
    }
  }

  /// 利用者選択セクション
  Widget _buildUserSelectionSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー
            Row(
              children: [
                Icon(Icons.people, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  '対象利用者',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                const Spacer(),
                // 選択数表示
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_selectedUsers.length} / ${_users.length} 名選択中',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 全選択/全解除ボタン
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedUsers = _users.map((u) => u.name).toSet();
                    });
                  },
                  icon: const Icon(Icons.select_all, size: 18),
                  label: const Text('全選択'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedUsers.clear();
                    });
                  },
                  icon: const Icon(Icons.deselect, size: 18),
                  label: const Text('全解除'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),

            // 利用者リスト
            if (_isUsersLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_users.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    '利用者が登録されていません',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              // チェックボックスリスト
              ...List.generate(_users.length, (index) {
                final user = _users[index];
                final isSelected = _selectedUsers.contains(user.name);
                final displayName = user.isDeparted
                    ? '${user.name}（退所）'
                    : user.name;
                return CheckboxListTile(
                  value: isSelected,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedUsers.add(user.name);
                      } else {
                        _selectedUsers.remove(user.name);
                      }
                    });
                  },
                  title: Text(
                    displayName,
                    style: TextStyle(
                      color: user.isDeparted ? Colors.grey : null,
                    ),
                  ),
                  subtitle: Text(
                    user.furigana,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: Colors.blue,
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequiredTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool isRequired = true,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? tooltip,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // タイトル行（ラベル + 注意マーク）
          Row(
            children: [
              Text(
                isRequired ? '$label *' : label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              if (tooltip != null) _buildTooltipIcon(tooltip),
            ],
          ),
          const SizedBox(height: 6),
          // 入力フィールド
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
            validator: isRequired
                ? (value) {
                    if (value == null || value.isEmpty) {
                      return '$labelを入力してください';
                    }
                    return null;
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> options,
    required void Function(String?) onChanged,
    bool isRequired = false,
    String? tooltip,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // タイトル行（ラベル + 注意マーク）
          Row(
            children: [
              Text(
                isRequired ? '$label *' : label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              if (tooltip != null) _buildTooltipIcon(tooltip),
            ],
          ),
          const SizedBox(height: 6),
          // プルダウン
          DropdownButtonFormField<String>(
            value: value,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('選択してください'),
              ),
              ...options.map((option) => DropdownMenuItem<String>(
                    value: option,
                    child: Text(option),
                  )),
            ],
            onChanged: onChanged,
            validator: isRequired
                ? (value) {
                    if (value == null || value.isEmpty) {
                      return '$labelを選択してください';
                    }
                    return null;
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildCheckbox({
    required String label,
    required bool value,
    required void Function(bool?) onChanged,
    String? tooltip,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
          if (tooltip != null) _buildTooltipIcon(tooltip),
        ],
      ),
    );
  }

  Widget _buildDisabledField({required String label}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        enabled: false,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.grey.shade200,
        ),
      ),
    );
  }

  /// ツールチップアイコン（注意マーク）- ホバーで表示
  Widget _buildTooltipIcon(String message) {
    return Padding(
      padding: const EdgeInsets.only(left: 6.0),
      child: Tooltip(
        message: message,
        preferBelow: false,
        showDuration: const Duration(seconds: 10),
        waitDuration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(12),
        textStyle: const TextStyle(
          fontSize: 13,
          color: Colors.white,
          height: 1.4,
        ),
        decoration: BoxDecoration(
          color: Colors.grey.shade800,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.info_outline,
          color: Colors.orange,
          size: 18,
        ),
      ),
    );
  }

  /// コンボボックス（プルダウン選択 + 手入力）
  Widget _buildComboField({
    required TextEditingController controller,
    required String label,
    required List<String> options,
    String? hint,
    String? tooltip,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // タイトル行（ラベル + 注意マーク）
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              if (tooltip != null) _buildTooltipIcon(tooltip),
            ],
          ),
          const SizedBox(height: 6),
          // 入力フィールド
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              hintText: hint,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              suffixIcon: PopupMenuButton<String>(
                icon: const Icon(Icons.arrow_drop_down),
                tooltip: '選択肢から選ぶ',
                onSelected: (String value) {
                  controller.text = value;
                },
                itemBuilder: (BuildContext context) {
                  return options.map((String option) {
                    return PopupMenuItem<String>(
                      value: option,
                      child: Text(option.isEmpty ? '（空欄）' : option),
                    );
                  }).toList();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('必須項目を入力してください'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 保存データを構築
      final settings = {
        // テキストフィールド
        'serviceYearMonth': _serviceYearMonthController.text,
        'corporateName': _corporateNameController.text,
        'representative': _representativeController.text,
        'businessName': _businessNameController.text,
        'abbreviation': _abbreviationController.text,
        'manager': _managerController.text,
        'businessNumber': _businessNumberController.text,
        'postalCode': _postalCodeController.text,
        'address': _addressController.text,
        'phone': _phoneController.text,
        'capacity': _capacityController.text,
        'typeCapacity': _typeCapacityController.text,
        'standardUnit': _standardUnitController.text,
        'transitionWorkers': _transitionWorkersController.text,
        'invoicePosition': _invoicePositionController.text,
        'invoiceName': _invoiceNameController.text,
        'invoiceNote': _invoiceNoteController.text,
        'expense1': _expense1Controller.text,
        'expense2': _expense2Controller.text,

        // コンボボックス
        'overCapacity': _overCapacityController.text,
        'employeeShortage': _employeeShortageController.text,
        'serviceManagerShortage': _serviceManagerShortageController.text,
        'severeSupport': _severeSupportController.text,
        'targetWageInstructor': _targetWageInstructorController.text,
        'severeSupport2': _severeSupport2Controller.text,
        'medicalCooperation': _medicalCooperationController.text,

        // プルダウン
        'type': _selectedType ?? '',
        'wageCategory': _selectedWageCategory ?? '',
        'regionCategory': _selectedRegionCategory ?? '',
        'welfareStaffAddition': _selectedWelfareStaffAddition ?? '',
        'transportAddition': _selectedTransportAddition ?? '',
        'visualHearingSpeechSupport': _selectedVisualHearingSpeechSupport ?? '',
        'welfareImprovement': _selectedWelfareImprovement ?? '',

        // チェックボックス（チェック時は「○」U+25CB）
        'isPublic': _isPublic ? '\u25CB' : '',
        'hasTransitionSupport': _hasTransitionSupport ? '\u25CB' : '',
        'hasTargetWageAchievement': _hasTargetWageAchievement ? '\u25CB' : '',
        'hasRestraintReduction': _hasRestraintReduction ? '\u25CB' : '',
        'hasRegionalLifeSupport': _hasRegionalLifeSupport ? '\u25CB' : '',
        'hasShortTimeReduction': _hasShortTimeReduction ? '\u25CB' : '',
        'hasInfoDisclosureReduction': _hasInfoDisclosureReduction ? '\u25CB' : '',
        'hasBcpReduction': _hasBcpReduction ? '\u25CB' : '',
        'hasAbusePreventionReduction': _hasAbusePreventionReduction ? '\u25CB' : '',
        'hasHigherBrainSupport': _hasHigherBrainSupport ? '\u25CB' : '',
        'isDesignatedFacility': _isDesignatedFacility ? '\u25CB' : '',
      };

      await _billingService.saveBillingSettings(settings);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('設定を保存しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
