import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../services/master_service.dart';
import '../../widgets/searchable_dropdown.dart';
import '../../theme/app_theme_v2.dart';
import 'checkin_screen.dart';
import 'checkout_screen.dart';

/// 利用者が自分の名前を選ぶ画面（V2デザイン）
class UserSelectScreen extends StatefulWidget {
  const UserSelectScreen({super.key});

  @override
  State<UserSelectScreen> createState() => _UserSelectScreenState();
}

class _UserSelectScreenState extends State<UserSelectScreen> {
  final MasterService _masterService = MasterService();
  List<User> _users = [];
  User? _selectedUser;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  /// 利用者一覧を読み込む
  Future<void> _loadUsers() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final users = await _masterService.getActiveUsers();

      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'データの読み込みに失敗しました\n$e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CleanScaffold(
      appBar: const CleanAppBar(title: '利用者選択'),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppThemeV2.primaryGreen,
              ),
            )
          : _errorMessage != null
              ? _buildErrorView()
              : _buildUserSelectView(),
    );
  }

  /// エラー表示
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: CleanCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: AppThemeV2.errorColor,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: AppThemeV2.bodyLarge,
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: '再読み込み',
                icon: Icons.refresh,
                onPressed: _loadUsers,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 利用者選択画面
  Widget _buildUserSelectView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // タピルマスコット画像
          Center(
            child: Image.asset(
              'assets/images/tapir_select_name.png',
              height: 160,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 24),

          // タイトル
          CleanCard(
            child: Column(
              children: [
                Text(
                  'あなたの名前を選んでください',
                  textAlign: TextAlign.center,
                  style: AppThemeV2.headlineSmall,
                ),
                const SizedBox(height: 24),

                // 名前選択のプルダウン（検索機能付き）
                SearchableDropdown<User>(
                  value: _selectedUser,
                  items: _users,
                  itemLabel: (user) => user.name,
                  onChanged: (user) {
                    setState(() {
                      _selectedUser = user;
                    });
                  },
                  hint: '名前を入力して検索...',
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // 出勤ボタン
          _ActionButton(
            label: '出勤する',
            icon: Icons.login,
            color: AppThemeV2.primaryGreen,
            onTap: _selectedUser == null
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CheckinScreen(
                          userName: _selectedUser!.name,
                        ),
                      ),
                    );
                  },
          ),
          const SizedBox(height: 16),

          // 退勤ボタン
          _ActionButton(
            label: '退勤する',
            icon: Icons.logout,
            color: AppThemeV2.infoColor,
            onTap: _selectedUser == null
                ? null
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CheckoutScreen(
                          userName: _selectedUser!.name,
                        ),
                      ),
                    );
                  },
          ),
        ],
      ),
    );
  }
}

/// アクションボタン（大きめのボタン）
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: isEnabled ? color : color.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
