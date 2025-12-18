import 'package:flutter/material.dart';
import '../../models/facility.dart';
import '../../services/facility_service.dart';

/// 施設編集画面
class FacilityEditScreen extends StatefulWidget {
  final Facility facility;

  const FacilityEditScreen({
    super.key,
    required this.facility,
  });

  @override
  State<FacilityEditScreen> createState() => _FacilityEditScreenState();
}

class _FacilityEditScreenState extends State<FacilityEditScreen> {
  final FacilityService _facilityService = FacilityService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _facilityNameController;
  late TextEditingController _adminNameController;
  late TextEditingController _adminEmailController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;

  bool _isLoading = false;
  late bool _timeRounding;

  @override
  void initState() {
    super.initState();
    // 既存の施設情報で初期化
    _facilityNameController = TextEditingController(text: widget.facility.facilityName);
    _adminNameController = TextEditingController(text: widget.facility.adminName);
    _adminEmailController = TextEditingController(text: widget.facility.adminEmail);
    _addressController = TextEditingController(text: widget.facility.address ?? '');
    _phoneController = TextEditingController(text: widget.facility.phone ?? '');
    _timeRounding = widget.facility.timeRounding == 'オン';
  }

  @override
  void dispose() {
    _facilityNameController.dispose();
    _adminNameController.dispose();
    _adminEmailController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _updateFacility() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final updateData = {
        'facilityName': _facilityNameController.text.trim(),
        'adminName': _adminNameController.text.trim(),
        'adminEmail': _adminEmailController.text.trim(),
        'address': _addressController.text.trim(),
        'phone': _phoneController.text.trim(),
        'timeRounding': _timeRounding ? 'オン' : 'オフ',
      };

      // 空文字のフィールドを削除（timeRoundingは残す）
      updateData.removeWhere((key, value) => value.isEmpty && key != 'timeRounding');

      final response = await _facilityService.updateFacility(
        widget.facility.facilityId,
        updateData,
      );

      if (mounted) {
        if (response['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('施設情報を更新しました')),
          );
          Navigator.pop(context, true); // 更新成功
        } else {
          _showErrorDialog(response['error'] ?? '更新に失敗しました');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('更新に失敗しました\n$e');
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
        title: const Text('施設情報編集'),
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
              // 施設ID（編集不可）
              Card(
                color: Colors.grey.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '施設ID',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.facility.facilityId,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 施設名
              TextFormField(
                controller: _facilityNameController,
                decoration: const InputDecoration(
                  labelText: '施設名 *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
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

              // 施設住所
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: '施設住所',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
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
                ),
                keyboardType: TextInputType.phone,
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

              // 更新ボタン
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _updateFacility,
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
                label: Text(_isLoading ? '更新中...' : '更新する'),
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
