import 'package:flutter/material.dart';

import 'storage_pickup_code_page.dart';

const _storageGold = Color(0xFFC9B69E);

enum _StorageCategory { wine, item }

class PrivateStoragePage extends StatefulWidget {
  const PrivateStoragePage({super.key});

  @override
  State<PrivateStoragePage> createState() => _PrivateStoragePageState();
}

class _PrivateStoragePageState extends State<PrivateStoragePage> {
  final _pageController = PageController();
  _StorageCategory _category = _StorageCategory.wine;
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectCategory(_StorageCategory category) {
    if (_category == category) return;
    setState(() {
      _category = category;
      _page = 0;
    });
    _pageController.jumpToPage(0);
  }

  Future<void> _showEmptyMessage() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF17130F),
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 6, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '私人储物柜',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _category == _StorageCategory.wine
                    ? '当前没有可展示的存酒'
                    : '当前没有可展示的物品',
                style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 14),
              ),
              const SizedBox(height: 6),
              const Text(
                '取件凭证仅在核验到有效存酒或物品后生成。',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0x55FFFFFF), fontSize: 12),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  key: const ValueKey('storage-open-pickup-demo'),
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const StoragePickupCodePage(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _storageGold,
                    side: const BorderSide(color: _storageGold),
                  ),
                  child: const Text('查看取件凭证'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  style: FilledButton.styleFrom(
                    backgroundColor: _storageGold,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('知道了'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.48),
            radius: 0.92,
            colors: [Color(0xEF252018), Colors.black],
            stops: [0, 1],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const SizedBox(
                height: 58,
                child: Center(
                  child: Text(
                    '私人储物柜',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Semantics(
                    key: const ValueKey('storage-empty-info'),
                    button: true,
                    label: '储物柜为空，查看说明',
                    child: InkResponse(
                      onTap: _showEmptyMessage,
                      radius: 40,
                      child: Image.asset(
                        'assets/legacy/storage/fail.png',
                        width: 58,
                        height: 58,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 479,
                child: Column(
                  children: [
                    SizedBox(
                      width: 322,
                      height: 34,
                      child: Row(
                        children: [
                          _CategoryTab(
                            label: '酒',
                            selected: _category == _StorageCategory.wine,
                            onTap: () => _selectCategory(_StorageCategory.wine),
                          ),
                          _CategoryTab(
                            label: '物',
                            selected: _category == _StorageCategory.item,
                            onTap: () => _selectCategory(_StorageCategory.item),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 7),
                    SizedBox(
                      width: 322,
                      height: 322,
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: 2,
                        onPageChanged: (value) => setState(() => _page = value),
                        itemBuilder: (_, pageIndex) => _EmptyStorageGrid(
                          category: _category,
                          pageIndex: pageIndex,
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        2,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: index == _page
                                ? _storageGold
                                : const Color(0x30FFFFFF),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryTab extends StatelessWidget {
  const _CategoryTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: ValueKey('storage-tab-$label-${selected ? 'selected' : 'idle'}'),
      selected: selected,
      button: true,
      label: '$label，储物分类${selected ? '，已选中' : ''}',
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 31,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          padding: const EdgeInsets.symmetric(horizontal: 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: selected
                ? const Border(
                    bottom: BorderSide(color: _storageGold, width: 1),
                  )
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0x66FFFFFF),
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyStorageGrid extends StatelessWidget {
  const _EmptyStorageGrid({required this.category, required this.pageIndex});

  final _StorageCategory category;
  final int pageIndex;

  @override
  Widget build(BuildContext context) {
    final categoryLabel = category == _StorageCategory.wine ? '酒' : '物';
    return Semantics(
      key: ValueKey('storage-grid-$categoryLabel-${pageIndex + 1}'),
      label: '$categoryLabel储物格，第${pageIndex + 1}页，9 个空格',
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: 9,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
        ),
        itemBuilder: (_, _) => DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0x55C9B69E), width: 1),
            gradient: const RadialGradient(
              center: Alignment(0, 1),
              radius: 1.1,
              colors: [Color(0xFF7A6750), Color(0xFF443626)],
            ),
          ),
        ),
      ),
    );
  }
}
