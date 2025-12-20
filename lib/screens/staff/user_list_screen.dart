import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../services/user_service.dart';
import 'user_form_screen.dart';

/// 利用者一覧画面（支援者用）
class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final UserService _userService = UserService();
  List<User> _users = [];
  List<User> _filteredUsers = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _filterStatus = 'all'; // 'all', '契約中', '退所済み'
  String _searchQuery = '';

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

      final users = await _userService.getUserList();

      setState(() {
        _users = users;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '利用者一覧の読み込みに失敗しました\n$e';
        _isLoading = false;
      });
    }
  }

  /// フィルタを適用
  void _applyFilters() {
    _filteredUsers = _users.where((user) {
      // ステータスフィルタ
      if (_filterStatus != 'all' && user.status != _filterStatus) {
        return false;
      }

      // 検索フィルタ
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        return user.name.toLowerCase().contains(query) ||
            user.furigana.toLowerCase().contains(query);
      }

      return true;
    }).toList();
  }

  /// 新規登録画面へ遷移
  void _navigateToCreateScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const UserFormScreen(),
      ),
    );

    if (result == true) {
      _loadUsers(); // 作成成功時は一覧を再読み込み
    }
  }

  /// 編集画面へ遷移
  void _navigateToEditScreen(User user) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserFormScreen(user: user),
      ),
    );

    if (result == true) {
      _loadUsers(); // 更新成功時は一覧を再読み込み
    }
  }

  /// 契約状態を変更
  Future<void> _changeUserStatus(User user) async {
    // 現在の状態と異なる状態を選択肢として表示
    final currentStatus = user.status;
    final newStatus = currentStatus == '契約中' ? '退所済み' : '契約中';

    // 退所日入力用コントローラー（退所済みに変更する場合のみ使用）
    final leaveDateController = TextEditingController();

    // 確認ダイアログ
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('契約状態の変更'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${user.name}さんの契約状態を変更しますか？'),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('現在: '),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: currentStatus == '契約中' ? Colors.orange : Colors.grey,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      currentStatus,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('変更後: '),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: newStatus == '契約中' ? Colors.orange : Colors.grey,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      newStatus,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
              // 退所済みに変更する場合のみ退所日入力フィールドを表示
              if (newStatus == '退所済み') ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  '退所日を入力してください',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: leaveDateController,
                  decoration: const InputDecoration(
                    labelText: '退所日',
                    hintText: '例: 20251231（8桁の数字）',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                    counterText: '',
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('変更'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // 退所日を取得（退所済みに変更する場合のみ）
      final leaveDate = newStatus == '退所済み' ? leaveDateController.text.trim() : null;

      await _userService.changeUserStatus(
        user.rowNumber!,
        newStatus,
        leaveDate: leaveDate,
      );

      leaveDateController.dispose();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.name}さんの契約状態を「$newStatus」に変更しました')),
        );
        _loadUsers(); // リスト再読み込み
      }
    } catch (e) {
      leaveDateController.dispose();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('契約状態の変更に失敗しました: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('利用者管理'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
            tooltip: '再読み込み',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterChips(),
          _buildUserCount(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? _buildErrorView()
                    : _buildUserList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreateScreen,
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  /// 検索バー
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        decoration: const InputDecoration(
          hintText: '名前またはフリガナで検索',
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
            _applyFilters();
          });
        },
      ),
    );
  }

  /// フィルタチップ
  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          const Text('絞り込み: ', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          _buildFilterChip('すべて', 'all'),
          const SizedBox(width: 8),
          _buildFilterChip('契約中', '契約中'),
          const SizedBox(width: 8),
          _buildFilterChip('退所済み', '退所済み'),
        ],
      ),
    );
  }

  /// フィルタチップ
  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterStatus = value;
          _applyFilters();
        });
      },
      selectedColor: Colors.orange.shade100,
    );
  }

  /// 利用者数表示
  Widget _buildUserCount() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        '${_filteredUsers.length}人',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  /// エラー表示
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadUsers,
              icon: const Icon(Icons.refresh),
              label: const Text('再読み込み'),
            ),
          ],
        ),
      ),
    );
  }

  /// 利用者一覧
  Widget _buildUserList() {
    if (_filteredUsers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '利用者がいません',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        return _buildUserCard(user);
      },
    );
  }

  /// 利用者カード
  Widget _buildUserCard(User user) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: user.isActive ? Colors.green : Colors.grey,
          child: Text(
            user.name.substring(0, 1),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          user.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('フリガナ: ${user.furigana}'),
            Text('ステータス: ${user.status}'),
            if (user.mobilePhone != null && user.mobilePhone!.isNotEmpty)
              Text('電話: ${user.mobilePhone}'),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _navigateToEditScreen(user);
            } else if (value == 'change_status') {
              _changeUserStatus(user);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('編集'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'change_status',
              child: Row(
                children: [
                  Icon(Icons.swap_horiz, size: 20, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('契約状態の変更', style: TextStyle(color: Colors.orange)),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _navigateToEditScreen(user),
      ),
    );
  }
}
