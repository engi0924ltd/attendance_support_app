import 'package:flutter/material.dart';

/// 検索機能付きプルダウン（インライン検索版）
/// 利用者選択など、多くの選択肢がある場合に使用
/// テキスト入力で絞り込み、ドロップダウンで選択
class SearchableDropdown<T> extends StatefulWidget {
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final String? Function(T)? itemSubtitle;
  final void Function(T?) onChanged;
  final String hint;
  final String searchHint;
  final bool enabled;

  const SearchableDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.itemLabel,
    this.itemSubtitle,
    required this.onChanged,
    this.hint = '選択してください',
    this.searchHint = '名前で検索...',
    this.enabled = true,
  });

  @override
  State<SearchableDropdown<T>> createState() => _SearchableDropdownState<T>();
}

class _SearchableDropdownState<T> extends State<SearchableDropdown<T>> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();

  OverlayEntry? _overlayEntry;
  List<T> _filteredItems = [];
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _filteredItems = widget.items;

    // 初期値がある場合はテキストフィールドに表示
    if (widget.value != null) {
      _controller.text = widget.itemLabel(widget.value as T);
    }

    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(SearchableDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 外部から値が変更された場合
    if (widget.value != oldWidget.value) {
      if (widget.value != null) {
        _controller.text = widget.itemLabel(widget.value as T);
      } else {
        _controller.clear();
      }
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    _controller.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _showOverlay();
    } else {
      // フォーカスが外れたら少し遅延してから閉じる（タップ選択のため）
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!_focusNode.hasFocus) {
          _removeOverlay();
        }
      });
    }
  }

  void _filterItems(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredItems = widget.items;
      } else {
        final lowerQuery = query.toLowerCase();
        _filteredItems = widget.items.where((item) {
          final label = widget.itemLabel(item).toLowerCase();
          return label.contains(lowerQuery);
        }).toList();
      }
    });
    _updateOverlay();
  }

  void _showOverlay() {
    if (_isOpen) return;

    _isOpen = true;
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    if (!_isOpen) return;

    _isOpen = false;
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _updateOverlay() {
    _overlayEntry?.markNeedsBuild();
  }

  void _selectItem(T item) {
    _controller.text = widget.itemLabel(item);
    widget.onChanged(item);
    _focusNode.unfocus();
    _removeOverlay();
  }

  void _clearSelection() {
    _controller.clear();
    widget.onChanged(null);
    _filteredItems = widget.items;
    _updateOverlay();
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: _buildDropdownList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownList() {
    if (_filteredItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: const Text(
          '該当する項目がありません',
          style: TextStyle(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) {
        final item = _filteredItems[index];
        final isSelected = widget.value != null &&
            widget.itemLabel(item) == widget.itemLabel(widget.value as T);

        return InkWell(
          onTap: () => _selectItem(item),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? Colors.orange.shade50 : null,
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.shade200,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                // アバター
                CircleAvatar(
                  radius: 16,
                  backgroundColor: isSelected
                      ? Colors.orange
                      : Colors.grey.shade300,
                  child: Text(
                    widget.itemLabel(item).isNotEmpty
                        ? widget.itemLabel(item)[0]
                        : '?',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 名前
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.itemLabel(item),
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 15,
                        ),
                      ),
                      if (widget.itemSubtitle != null)
                        Text(
                          widget.itemSubtitle!(item) ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                    ],
                  ),
                ),
                // 選択済みマーク
                if (isSelected)
                  const Icon(Icons.check, color: Colors.orange, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        decoration: InputDecoration(
          hintText: widget.value == null ? widget.hint : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: widget.enabled ? _clearSelection : null,
                )
              : const Icon(Icons.arrow_drop_down),
        ),
        onChanged: _filterItems,
        onTap: () {
          // タップ時に全選択して入力しやすく
          _controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _controller.text.length,
          );
          _filteredItems = widget.items;
          if (!_isOpen) {
            _showOverlay();
          }
        },
      ),
    );
  }
}
