import 'package:flutter/material.dart';
import '../../services/tasks_service.dart';

/// 作業登録・編集画面
/// 支援者・施設管理者共通で使用
class TasksSettingsScreen extends StatefulWidget {
  final String? facilityGasUrl;

  const TasksSettingsScreen({
    super.key,
    this.facilityGasUrl,
  });

  @override
  State<TasksSettingsScreen> createState() => _TasksSettingsScreenState();
}

class _TasksSettingsScreenState extends State<TasksSettingsScreen> {
  late TasksService _tasksService;
  List<String> _tasks = [];
  bool _isLoading = true;
  final TextEditingController _addController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tasksService = TasksService(facilityGasUrl: widget.facilityGasUrl);
    _loadTasks();
  }

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    final tasks = await _tasksService.getTasks();
    setState(() {
      _tasks = tasks;
      _isLoading = false;
    });
  }

  Future<void> _addTask() async {
    final name = _addController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('作業名を入力してください')),
      );
      return;
    }

    // 重複チェック
    if (_tasks.contains(name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('同じ作業が既に存在します')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final success = await _tasksService.addTask(name);

    if (success) {
      _addController.clear();
      await _loadTasks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('作業を追加しました')),
        );
      }
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('作業の追加に失敗しました')),
        );
      }
    }
  }

  Future<void> _deleteTask(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('確認'),
        content: Text('「${_tasks[index]}」を削除しますか？'),
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

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    final success = await _tasksService.deleteTask(index);

    if (success) {
      await _loadTasks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('作業を削除しました')),
        );
      }
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('作業の削除に失敗しました')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('作業登録・編集'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 追加フォーム
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _addController,
                          decoration: const InputDecoration(
                            labelText: '新しい作業',
                            hintText: '例：梱包作業',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _addTask(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _addTask,
                        icon: const Icon(Icons.add),
                        label: const Text('追加'),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                // 一覧ヘッダー
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '登録済み作業（${_tasks.length}/22件）',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      IconButton(
                        onPressed: _loadTasks,
                        icon: const Icon(Icons.refresh),
                        tooltip: '更新',
                      ),
                    ],
                  ),
                ),
                // 一覧
                Expanded(
                  child: _tasks.isEmpty
                      ? const Center(
                          child: Text(
                            '作業が登録されていません',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _tasks.length,
                          itemBuilder: (context, index) {
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.shade100,
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: Colors.blue.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(_tasks[index]),
                              trailing: IconButton(
                                onPressed: () => _deleteTask(index),
                                icon: const Icon(Icons.delete_outline),
                                color: Colors.red,
                                tooltip: '削除',
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
