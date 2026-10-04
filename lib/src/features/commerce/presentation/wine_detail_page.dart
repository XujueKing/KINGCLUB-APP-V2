import 'package:flutter/material.dart';

import '../../../core/design_system/king_components.dart';
import '../data/wine_stories.dart';
import 'ordering_entry_status.dart';

/// Reading-only route: ordering remains in the live catalog, preserving its cart.
class WineDetailPage extends StatelessWidget {
  const WineDetailPage({
    super.key,
    required this.name,
    required this.englishName,
    required this.specifications,
    required this.price,
    required this.image,
    required this.story,
    required this.locale,
  });

  final String name, englishName, specifications, price;
  final Widget image;
  final WineStory story;
  final Locale locale;

  String _text(List<String> values) => OrderingEntryStatus.text(locale, values);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: kingAppBar(
      context: context,
      centerTitle: true,
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      leading: KingBackButton(
        onPressed: () => Navigator.of(context).pop(),
        tooltip: _text(['返回', 'Back', '返回', 'ย้อนกลับ']),
      ),
      title: Text(
        _text(['商品详情', 'Product details', '商品詳情', 'รายละเอียดสินค้า']),
        style: const TextStyle(fontSize: 18, color: Colors.white),
      ),
    ),
    body: SafeArea(
      top: false,
      child: SingleChildScrollView(
        key: const ValueKey('wine-detail-scroll'),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 280,
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14120F),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(child: image),
                ),
                const SizedBox(height: 24),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (englishName != name) ...[
                  const SizedBox(height: 6),
                  Text(
                    englishName,
                    style: const TextStyle(
                      color: Color(0xFFC9B69E),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  specifications,
                  style: const TextStyle(
                    color: Color(0xFFAAAAAA),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '¥ $price',
                  style: const TextStyle(
                    color: Color(0xFFE8D7BD),
                    fontSize: 26,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 22),
                  child: Divider(color: Color(0xFF302820), height: 1),
                ),
                Text(
                  _text([
                    '酒款介绍',
                    'About this drink',
                    '酒款介紹',
                    'เกี่ยวกับเครื่องดื่มนี้',
                  ]),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _text(story.introductions),
                  key: const ValueKey('wine-introduction'),
                  style: const TextStyle(
                    color: Color(0xFFC9B69E),
                    fontSize: 16,
                    height: 1.8,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE8D7BD),
                      side: const BorderSide(color: Color(0xFF655440)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      _text([
                        '返回点单',
                        'Back to menu',
                        '返回點單',
                        'กลับไปสั่งเครื่องดื่ม',
                      ]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
