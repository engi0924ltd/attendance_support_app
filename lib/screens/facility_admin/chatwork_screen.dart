import 'package:flutter/material.dart';
import '../../services/attendance_service.dart';
import '../../theme/app_theme_v2.dart';

/// Chatwork連絡画面（施設管理者用）
/// デフォルト全員選択 → チェック外すと選択送信
class FacilityAdminChatworkScreen extends StatefulWidget {
  const FacilityAdminChatworkScreen({super.key});

  @override
  State<FacilityAdminChatworkScreen> createState() => _FacilityAdminChatworkScreenState();
}

class _FacilityAdminChatworkScreenState extends State<FacilityAdminChatworkScreen> {
  final _messageController = TextEditingController();
  final AttendanceService _attendanceService = AttendanceService();

  bool _isLoading = false;
  bool _isSending = false;
  List<Map<String, dynamic>> _users = [];
  Set<String> _selectedUsers = {};
  String? _errorMessage;
  int _sentCount = 0;
  int _failedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  /// ルームIDを持つ利用者一覧を読み込む（デフォルト全員選択）
  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final users = await _attendanceService.getChatworkUsers();
      // デフォルトで全員選択
      final usersWithRoom = users.where((u) =>
        u['chatworkRoomId'] != null && u['chatworkRoomId'].toString().isNotEmpty
      ).map((u) => u['userName'] as String).toSet();
      setState(() {
        _users = users;
        _selectedUsers = usersWithRoom;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = '利用者の読み込みに失敗しました: $e';
        _isLoading = false;
      });
    }
  }

  /// 送信を実行
  Future<void> _sendBroadcast() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('メッセージを入力してください'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('送信先を選択してください'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('送信確認'),
        content: Text('${_selectedUsers.length}名の利用者にメッセージを送信します。\nよろしいですか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('送信'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isSending = true;
      _sentCount = 0;
      _failedCount = 0;
    });

    try {
      final result = await _attendanceService.sendChatworkBroadcast(
        message,
        selectedUsers: _selectedUsers.toList(),
      );

      if (result['errors'] != null && (result['errors'] as List).isNotEmpty) {
        debugPrint('Chatwork送信エラー詳細: ${result['errors']}');
      }

      setState(() {
        _sentCount = result['sentCount'] ?? 0;
        _failedCount = result['failedCount'] ?? 0;
        _isSending = false;
      });

      if (mounted) {
        _showResultDialog(errors: result['errors'] as List?);
      }
    } catch (e) {
      setState(() {
        _isSending = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('送信エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showResultDialog({List? errors}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _failedCount == 0 ? Icons.check_circle : Icons.warning,
              color: _failedCount == 0 ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            const Text('送信完了'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('送信成功: $_sentCount 件'),
            if (_failedCount > 0)
              Text(
                '送信失敗: $_failedCount 件',
                style: const TextStyle(color: Colors.red),
              ),
            if (errors != null && errors.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('エラー詳細:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...errors.map((e) => Text(
                e.toString(),
                style: const TextStyle(fontSize: 12, color: Colors.red),
              )),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (_failedCount == 0) {
                _messageController.clear();
              }
            },
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeV2.backgroundGrey,
      appBar: AppBar(
        title: const Text('チャットワーク連絡'),
        backgroundColor: AppThemeV2.errorColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppThemeV2.errorColor))
          : _errorMessage != null
              ? _buildErrorView()
              : _buildContent(),
    );
  }

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

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 送信先情報
          _buildRecipientsCard(),
          const SizedBox(height: 16),

          // メッセージ入力
          _buildMessageInput(),
          const SizedBox(height: 24),

          // 送信ボタン
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isSending ? null : _sendBroadcast,
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send),
              label: Text(_isSending ? '送信中...' : '送信 (${_selectedUsers.length}名)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 送信先一覧
          _buildUserList(),
        ],
      ),
    );
  }

  Widget _buildRecipientsCard() {
    final usersWithRoom = _users.where((u) => u['chatworkRoomId'] != null && u['chatworkRoomId'].toString().isNotEmpty).toList();
    final usersWithoutRoom = _users.where((u) => u['chatworkRoomId'] == null || u['chatworkRoomId'].toString().isEmpty).toList();

    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Text(
                  '送信先',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildCountChip('選択中', _selectedUsers.length, Colors.green),
                const SizedBox(width: 8),
                _buildCountChip('送信可能', usersWithRoom.length, Colors.blue),
                const SizedBox(width: 8),
                _buildCountChip('未設定', usersWithoutRoom.length, Colors.grey),
              ],
            ),
            if (usersWithoutRoom.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '※ルームIDが未設定の利用者には送信されません',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCountChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'メッセージ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              maxLines: 8,
              decoration: InputDecoration(
                hintText: '送信するメッセージを入力してください',
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey.shade400, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.red.shade400, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '※選択した利用者に同じメッセージが送信されます',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserList() {
    final usersWithRoom = _users.where((u) => u['chatworkRoomId'] != null && u['chatworkRoomId'].toString().isNotEmpty).toList();

    if (usersWithRoom.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.inbox, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 8),
                Text(
                  '送信可能な利用者がいません',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '送信先一覧 (${usersWithRoom.length}名)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedUsers = usersWithRoom
                              .map((u) => u['userName'] as String)
                              .toSet();
                        });
                      },
                      child: const Text('全選択'),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedUsers.clear();
                        });
                      },
                      child: const Text('全解除'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: usersWithRoom.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final user = usersWithRoom[index];
              final userName = user['userName'] as String? ?? '';
              final isSelected = _selectedUsers.contains(userName);

              return ListTile(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedUsers.remove(userName);
                    } else {
                      _selectedUsers.add(userName);
                    }
                  });
                },
                leading: CircleAvatar(
                  backgroundColor: Colors.red.shade100,
                  child: Text(
                    userName.isNotEmpty ? userName.substring(0, 1) : '?',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(userName),
                subtitle: Text(
                  'Room ID: ${user['chatworkRoomId']}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  color: isSelected ? Colors.green : Colors.grey,
                  size: 24,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
