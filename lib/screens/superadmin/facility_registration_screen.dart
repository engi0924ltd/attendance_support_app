import 'package:flutter/material.dart';
import '../../services/facility_service.dart';
import '../../models/facility.dart';
import 'facility_setup_wizard_screen.dart';

/// 新規施設登録画面
class FacilityRegistrationScreen extends StatefulWidget {
  const FacilityRegistrationScreen({super.key});

  @override
  State<FacilityRegistrationScreen> createState() =>
      _FacilityRegistrationScreenState();
}

class _FacilityRegistrationScreenState
    extends State<FacilityRegistrationScreen> {
  final FacilityService _facilityService = FacilityService();
  final _formKey = GlobalKey<FormState>();

  // 必須フィールド
  final TextEditingController _facilityIdController = TextEditingController();
  final TextEditingController _facilityNameController =
      TextEditingController();
  final TextEditingController _adminNameController = TextEditingController();
  final TextEditingController _adminEmailController = TextEditingController();
  final TextEditingController _adminPasswordController =
      TextEditingController();
  final TextEditingController _fiscalYearController = TextEditingController();

  // オプションフィールド
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _timeRounding = false; // 15分ごとに登録する

  @override
  void initState() {
    super.initState();
    // デフォルト年度を設定
    _fiscalYearController.text = DateTime.now().year.toString();
  }

  @override
  void dispose() {
    _facilityIdController.dispose();
    _facilityNameController.dispose();
    _adminNameController.dispose();
    _adminEmailController.dispose();
    _adminPasswordController.dispose();
    _fiscalYearController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _capacityController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _registerFacility() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final facilityData = {
        'facilityId': _facilityIdController.text.trim(),
        'facilityName': _facilityNameController.text.trim(),
        'adminName': _adminNameController.text.trim(),
        'adminEmail': _adminEmailController.text.trim(),
        'adminPassword': _adminPasswordController.text,
        'fiscalYear': _fiscalYearController.text.trim(),
        'address': _addressController.text.trim(),
        'phone': _phoneController.text.trim(),
        'capacity': _capacityController.text.trim(),
        'memo': _memoController.text.trim(),
        'timeRounding': _timeRounding ? 'オン' : 'オフ',
      };

      // 空文字のフィールドを削除
      facilityData.removeWhere((key, value) => value.isEmpty);

      final response = await _facilityService.createFacility(facilityData);

      if (mounted) {
        if (response['success'] == true) {
          // 登録された施設情報を取得
          final facilityData = response['data']['facility'];
          final facility = Facility.fromJson(facilityData);

          // セットアップウィザードに遷移
          final wizardResult = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => FacilitySetupWizardScreen(
                facility: facility,
              ),
            ),
          );

          // ウィザードから戻ってきたら、施設一覧に戻る
          if (mounted) {
            Navigator.pop(context, wizardResult ?? true);
          }
        } else {
          _showErrorDialog(response['error'] ?? '登録に失敗しました');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('登録に失敗しました\n$e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
        title: const Text('新規施設登録'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 説明テキスト
              Card(
                color: Colors.purple.shade50,
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '新規施設の登録',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '施設情報を入力してください。\n'
                        'テンプレートスプレッドシートが自動的にコピーされ、\n'
                        '新しい施設が登録されます。',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 必須項目セクション
              const Text(
                '必須項目',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 16),

              // 施設ID
              TextFormField(
                controller: _facilityIdController,
                decoration: const InputDecoration(
                  labelText: '施設ID（厚労省番号） *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                  hintText: '例: 1234567890',
                ),
                keyboardType: TextInputType.number,
                enabled: !_isLoading,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '施設IDを入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 施設名
              TextFormField(
                controller: _facilityNameController,
                decoration: const InputDecoration(
                  labelText: '施設名 *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                  hintText: '例: ○○就労継続支援B型事業所',
                ),
                enabled: !_isLoading,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '施設名を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 施設管理者名
              TextFormField(
                controller: _adminNameController,
                decoration: const InputDecoration(
                  labelText: '施設管理者名 *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                  hintText: '例: 山田太郎',
                ),
                enabled: !_isLoading,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '施設管理者名を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // メールアドレス
              TextFormField(
                controller: _adminEmailController,
                decoration: const InputDecoration(
                  labelText: 'メールアドレス *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                  hintText: 'admin@example.com',
                ),
                keyboardType: TextInputType.emailAddress,
                enabled: !_isLoading,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'メールアドレスを入力してください';
                  }
                  if (!value.contains('@')) {
                    return '正しいメールアドレスを入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // パスワード
              TextFormField(
                controller: _adminPasswordController,
                decoration: InputDecoration(
                  labelText: 'パスワード *',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  helperText: '大文字、小文字、数字を含む6文字以上',
                  helperMaxLines: 2,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscurePassword,
                enabled: !_isLoading,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'パスワードを入力してください';
                  }
                  if (value.length < 6) {
                    return 'パスワードは6文字以上で入力してください';
                  }
                  // 大文字チェック
                  if (!RegExp(r'[A-Z]').hasMatch(value)) {
                    return 'パスワードには大文字を含めてください';
                  }
                  // 小文字チェック
                  if (!RegExp(r'[a-z]').hasMatch(value)) {
                    return 'パスワードには小文字を含めてください';
                  }
                  // 数字チェック
                  if (!RegExp(r'[0-9]').hasMatch(value)) {
                    return 'パスワードには数字を含めてください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 年度
              TextFormField(
                controller: _fiscalYearController,
                decoration: const InputDecoration(
                  labelText: '年度 *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                  hintText: '例: 2025',
                ),
                keyboardType: TextInputType.number,
                enabled: !_isLoading,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '年度を入力してください';
                  }
                  final year = int.tryParse(value);
                  if (year == null || year < 2020 || year > 2100) {
                    return '正しい年度を入力してください（2020-2100）';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // オプション項目セクション
              const Text(
                'オプション項目',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // 施設住所
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: '施設住所',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                  hintText: '例: 東京都渋谷区...',
                ),
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),

              // 施設電話番号
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: '施設電話番号',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                  hintText: '例: 03-1234-5678',
                ),
                keyboardType: TextInputType.phone,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),

              // 利用者定員
              TextFormField(
                controller: _capacityController,
                decoration: const InputDecoration(
                  labelText: '利用者定員',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.groups),
                  hintText: '例: 20',
                ),
                keyboardType: TextInputType.number,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),

              // 備考
              TextFormField(
                controller: _memoController,
                decoration: const InputDecoration(
                  labelText: '備考',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                  hintText: '特記事項があれば入力してください',
                ),
                maxLines: 3,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 24),

              // 15分ごとに登録するチェックボックス
              Card(
                child: CheckboxListTile(
                  title: const Text('15分ごとに登録する'),
                  subtitle: const Text(
                    '出勤・退勤時間を15分単位に自動的に丸めます\n'
                    '（例: 9:18 → 9:15、9:23 → 9:30）',
                  ),
                  value: _timeRounding,
                  enabled: !_isLoading,
                  onChanged: (value) {
                    setState(() {
                      _timeRounding = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  secondary: const Icon(Icons.schedule, color: Colors.purple),
                ),
              ),
              const SizedBox(height: 32),

              // 登録ボタン
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _registerFacility,
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
                label: Text(_isLoading ? '登録中...' : '施設を登録'),
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
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
