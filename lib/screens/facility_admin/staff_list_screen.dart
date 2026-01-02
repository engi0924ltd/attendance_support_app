import 'package:flutter/material.dart';
import '../../models/staff.dart';
import '../../services/staff_service.dart';
import 'staff_form_screen.dart';

/// 職員一覧画面（施設管理者用）
class StaffListScreen extends StatefulWidget {
  final String? gasUrl; // 施設固有のGAS URL

  const StaffListScreen({super.key, this.gasUrl});

  @override
  State<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends State<StaffListScreen> {
  late final StaffService _staffService;
  List<Staff> _staffList = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _staffService = StaffService(facilityGasUrl: widget.gasUrl);
    _loadStaffList();
  }

  /// 職員一覧を読み込む
  Future<void> _loadStaffList() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final staffList = await _staffService.getStaffList();
      setState(() {
        _staffList = staffList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'データの読み込みに失敗しました\n$e';
        _isLoading = false;
      });
    }
  }

  /// 職員を削除
  Future<void> _deleteStaff(Staff staff) async {
    // 確認ダイアログ
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('${staff.name} を削除しますか？\nこの操作は取り消せません。'),
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

    try {
      await _staffService.deleteStaff(staff.rowNumber!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('職員を削除しました')),
        );
        _loadStaffList(); // リスト再読み込み
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('削除に失敗しました: $e')),
        );
      }
    }
  }

  /// 職員を追加
  Future<void> _addStaff() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => StaffFormScreen(gasUrl: widget.gasUrl),
      ),
    );

    if (result == true) {
      _loadStaffList(); // 追加後にリスト再読み込み
    }
  }

  /// 職員を編集
  Future<void> _editStaff(Staff staff) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => StaffFormScreen(
          staff: staff,
          gasUrl: widget.gasUrl,
        ),
      ),
    );

    if (result == true) {
      _loadStaffList(); // 編集後にリスト再読み込み
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('職員管理'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStaffList,
            tooltip: '更新',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addStaff,
        backgroundColor: Colors.blue,
        icon: const Icon(Icons.add),
        label: const Text('職員を追加'),
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
              onPressed: _loadStaffList,
              icon: const Icon(Icons.refresh),
              label: const Text('再読み込み'),
            ),
          ],
        ),
      );
    }

    if (_staffList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              '登録された職員がいません',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _addStaff,
              icon: const Icon(Icons.add),
              label: const Text('最初の職員を追加'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _staffList.length,
      itemBuilder: (context, index) {
        final staff = _staffList[index];
        return _buildStaffCard(staff);
      },
    );
  }

  Widget _buildStaffCard(Staff staff) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16.0),
        leading: CircleAvatar(
          backgroundColor: staff.isAdmin ? Colors.orange : Colors.blue,
          child: Icon(
            staff.isAdmin ? Icons.admin_panel_settings : Icons.person,
            color: Colors.white,
          ),
        ),
        title: Row(
          children: [
            Text(
              staff.name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: staff.isRetired ? Colors.grey : null,
              ),
            ),
            if (staff.isRetired) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '退職済',
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.email,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    staff.email,
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
                    color: staff.isAdmin ? Colors.orange : Colors.blue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    staff.role,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
                if (staff.jobType != null && staff.jobType!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      staff.jobType!,
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _editStaff(staff);
            } else if (value == 'delete') {
              _deleteStaff(staff);
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
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('削除', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
