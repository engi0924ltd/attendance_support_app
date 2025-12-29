import 'package:flutter/material.dart';
import '../../models/staff.dart';
import '../../services/staff_service.dart';
import '../../services/master_service.dart';

/// 職員登録・編集画面
class StaffFormScreen extends StatefulWidget {
  final Staff? staff; // 編集時は既存の職員データを渡す
  final String? gasUrl; // 施設固有のGAS URL

  const StaffFormScreen({super.key, this.staff, this.gasUrl});

  @override
  State<StaffFormScreen> createState() => _StaffFormScreenState();
}

class _StaffFormScreenState extends State<StaffFormScreen> {
  late final StaffService _staffService;
  late final MasterService _masterService;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  String _selectedRole = '従業員'; // デフォルトは従業員
  String? _selectedQualification; // 選択された資格
  String? _selectedPlacement; // 選択された配置
  String? _selectedJobType; // 選択された職種
  List<String> _qualificationOptions = []; // 資格選択肢
  List<String> _placementOptions = []; // 配置選択肢
  List<String> _jobTypeOptions = []; // 職種選択肢
  bool _isLoading = false;
  bool _isLoadingOptions = true;
  bool _obscurePassword = true;
  bool get _isEditMode => widget.staff != null;

  @override
  void initState() {
    super.initState();

    // サービスを初期化
    _staffService = StaffService(facilityGasUrl: widget.gasUrl);
    _masterService = MasterService(gasUrl: widget.gasUrl);

    // 編集モードの場合は既存データをセット
    _nameController = TextEditingController(text: widget.staff?.name ?? '');
    _emailController = TextEditingController(text: widget.staff?.email ?? '');
    _passwordController = TextEditingController();

    if (widget.staff != null) {
      _selectedRole = widget.staff!.role;
      _selectedQualification = widget.staff!.qualification;
      _selectedPlacement = widget.staff!.placement;
      _selectedJobType = widget.staff!.jobType;
    }

    // プルダウン選択肢を読み込む
    _loadDropdownOptions();
  }

  Future<void> _loadDropdownOptions() async {
    try {
      final options = await _masterService.getDropdownOptions(forceRefresh: true);
      if (mounted) {
        setState(() {
          _qualificationOptions = options.qualifications;
          _placementOptions = options.placements;
          _jobTypeOptions = options.jobTypes;
          _isLoadingOptions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingOptions = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
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
        await _staffService.updateStaff(
          rowNumber: widget.staff!.rowNumber!,
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          role: _selectedRole,
          password: _passwordController.text.isNotEmpty
              ? _passwordController.text
              : null,
          jobType: _selectedJobType,
          qualification: _selectedQualification,
          placement: _selectedPlacement,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('職員情報を更新しました')),
          );
          Navigator.pop(context, true); // 成功を通知して戻る
        }
      } else {
        // 新規登録
        await _staffService.createStaff(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          role: _selectedRole,
          jobType: _selectedJobType,
          qualification: _selectedQualification,
          placement: _selectedPlacement,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('職員を登録しました')),
          );
          Navigator.pop(context, true); // 成功を通知して戻る
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
        title: Text(_isEditMode ? '職員情報編集' : '職員登録'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 説明カード
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEditMode ? '職員情報の編集' : '新しい職員の登録',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isEditMode
                            ? '職員情報を変更できます。\nパスワードは変更する場合のみ入力してください。'
                            : '職員情報を入力してください。\nパスワードは大文字、小文字、数字を含む6文字以上で設定してください。\n職種は必須項目です。',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 職員名
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '職員名 *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                  hintText: '例: 山田太郎',
                ),
                enabled: !_isLoading,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '職員名を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // メールアドレス
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'メールアドレス *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                  hintText: 'staff@example.com',
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
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: _isEditMode ? 'パスワード（変更する場合のみ）' : 'パスワード *',
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
                  // 新規登録時は必須、編集時は任意
                  if (!_isEditMode && (value == null || value.isEmpty)) {
                    return 'パスワードを入力してください';
                  }

                  // パスワードが入力されている場合は強度チェック
                  if (value != null && value.isNotEmpty) {
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
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 権限
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: '権限 *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.security),
                ),
                items: const [
                  DropdownMenuItem(
                    value: '管理者',
                    child: Text('管理者（施設管理者と同等の権限）'),
                  ),
                  DropdownMenuItem(
                    value: '従業員',
                    child: Text('従業員（一般スタッフ）'),
                  ),
                ],
                onChanged: _isLoading
                    ? null
                    : (value) {
                        setState(() {
                          _selectedRole = value!;
                        });
                      },
              ),
              const SizedBox(height: 16),

              // 職種（必須）
              _isLoadingOptions
                  ? const SizedBox.shrink()
                  : DropdownButtonFormField<String>(
                      value: _selectedJobType,
                      decoration: const InputDecoration(
                        labelText: '職種 *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.work),
                      ),
                      items: _jobTypeOptions.map((option) {
                        return DropdownMenuItem<String>(
                          value: option,
                          child: Text(option),
                        );
                      }).toList(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '職種を選択してください';
                        }
                        return null;
                      },
                      onChanged: _isLoading
                          ? null
                          : (value) {
                              setState(() {
                                _selectedJobType = value;
                              });
                            },
                    ),
              const SizedBox(height: 16),

              // 保有福祉資格（任意）
              _isLoadingOptions
                  ? const Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<String>(
                      value: _selectedQualification,
                      decoration: const InputDecoration(
                        labelText: '保有福祉資格',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.card_membership),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('選択なし'),
                        ),
                        ..._qualificationOptions.map((option) {
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
                                _selectedQualification = value;
                              });
                            },
                    ),
              const SizedBox(height: 16),

              // 職員配置（必須）
              _isLoadingOptions
                  ? const SizedBox.shrink()
                  : DropdownButtonFormField<String>(
                      value: _selectedPlacement,
                      decoration: const InputDecoration(
                        labelText: '職員配置 *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      items: _placementOptions.map((option) {
                        return DropdownMenuItem<String>(
                          value: option,
                          child: Text(option),
                        );
                      }).toList(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '職員配置を選択してください';
                        }
                        return null;
                      },
                      onChanged: _isLoading
                          ? null
                          : (value) {
                              setState(() {
                                _selectedPlacement = value;
                              });
                            },
                    ),
              const SizedBox(height: 32),

              // 保存ボタン
              ElevatedButton.icon(
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
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
