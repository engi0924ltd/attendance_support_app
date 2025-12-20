import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../services/user_service.dart';
import 'user_form_screen.dart';

/// 利用者一覧画面（施設管理者用）
class UserListScreen extends StatefulWidget {
  final String? gasUrl; // 施設固有のGAS URL

  const UserListScreen({super.key, this.gasUrl});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  late final UserService _userService;
  List<User> _userList = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _userService = UserService(facilityGasUrl: widget.gasUrl);
    _loadUserList();
  }

  /// 利用者一覧を読み込む
  Future<void> _loadUserList() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userList = await _userService.getUserList();
      setState(() {
        _userList = userList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'データの読み込みに失敗しました\n$e';
        _isLoading = false;
      });
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
              Text('${user.name} の契約状態を変更しますか？'),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('現在: '),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: currentStatus == '契約中' ? Colors.purple : Colors.grey,
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
                      color: newStatus == '契約中' ? Colors.purple : Colors.grey,
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
            style: TextButton.styleFrom(foregroundColor: Colors.purple),
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
          SnackBar(content: Text('${user.name} の契約状態を「$newStatus」に変更しました')),
        );
        _loadUserList(); // リスト再読み込み
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

  /// 利用者を追加
  Future<void> _addUser() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => UserFormScreen(gasUrl: widget.gasUrl),
      ),
    );

    if (result == true) {
      _loadUserList(); // 追加後にリスト再読み込み
    }
  }

  /// 利用者を編集
  Future<void> _editUser(User user) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => UserFormScreen(
          user: user,
          gasUrl: widget.gasUrl,
        ),
      ),
    );

    if (result == true) {
      _loadUserList(); // 編集後にリスト再読み込み
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('利用者管理'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUserList,
            tooltip: '更新',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addUser,
        backgroundColor: Colors.purple,
        icon: const Icon(Icons.add),
        label: const Text('利用者を追加'),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadUserList,
              icon: const Icon(Icons.refresh),
              label: const Text('再読み込み'),
            ),
          ],
        ),
      );
    }

    if (_userList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              '登録された利用者がいません',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _addUser,
              icon: const Icon(Icons.add),
              label: const Text('最初の利用者を追加'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _userList.length,
      itemBuilder: (context, index) {
        final user = _userList[index];
        return _buildUserCard(user);
      },
    );
  }

  Widget _buildUserCard(User user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16.0),
        leading: CircleAvatar(
          backgroundColor: user.isActive ? Colors.purple : Colors.grey,
          child: Icon(
            user.isActive ? Icons.person : Icons.person_outline,
            color: Colors.white,
          ),
        ),
        title: Text(
          user.name,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.text_fields,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    user.furigana,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: user.isActive ? Colors.purple : Colors.grey,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    user.status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: _buildWeeklyScheduleBadges(user),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _editUser(user);
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
      ),
    );
  }

  /// 曜日別予定バッジを生成
  List<Widget> _buildWeeklyScheduleBadges(User user) {
    final schedule = user.weeklySchedule;
    final badges = <Widget>[];

    schedule.forEach((day, value) {
      if (value != null && value.isNotEmpty) {
        badges.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.purple.shade100,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              day,
              style: TextStyle(
                color: Colors.purple.shade700,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }
    });

    return badges;
  }
}
