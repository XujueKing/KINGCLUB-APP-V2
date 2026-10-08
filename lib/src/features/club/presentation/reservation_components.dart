import 'package:flutter/material.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/design_system/king_control_sizes.dart';
import '../../../core/design_system/king_language.dart';
import '../../../core/media/cached_media_image.dart';
import '../../../core/formatters/money.dart';

const reservationGold = Color(0xffcebea4);
String reservationText(BuildContext context, String values) {
  final parts = values.split('|');
  final i = kingLanguageIndex(Localizations.localeOf(context));
  return parts.length > i ? parts[i] : parts[0];
}

String reservationType(BuildContext c, String type) =>
    reservationText(c, switch (type) {
      'booth' => '卡座|Booth|卡座|บูธ',
      'room' => '包厢|Room|包廂|ห้องส่วนตัว',
      _ => '散台|Table|散台|โต๊ะ',
    });
String reservationMoney(Object cents) => moneyCents(cents);
String reservationDate(Object? value) {
  final date = DateTime.tryParse('$value')?.toLocal();
  if (date == null) return '—';
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

Widget reservationPanel(Widget child) => Padding(
  padding: const EdgeInsets.only(bottom: 16),
  child: Material(
    color: const Color(0xff202020),
    borderRadius: BorderRadius.circular(20),
    child: SizedBox(
      width: double.infinity,
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    ),
  ),
);
Widget reservationRow(String label, String value) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 8),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 15),
        ),
      ),
      const SizedBox(width: 16),
      Flexible(
        child: Text(
          value,
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 16),
        ),
      ),
    ],
  ),
);
Widget reservationButton(
  String label,
  VoidCallback? action, {
  bool outline = false,
}) => SizedBox(
  width: double.infinity,
  height: kingControlHeight,
  child: outline
      ? OutlinedButton(
          onPressed: action,
          style: OutlinedButton.styleFrom(
            shape: const StadiumBorder(),
            side: const BorderSide(color: reservationGold),
            foregroundColor: reservationGold,
          ),
          child: Text(label),
        )
      : FilledButton(
          onPressed: action,
          style: FilledButton.styleFrom(
            shape: const StadiumBorder(),
            backgroundColor: reservationGold,
            foregroundColor: Colors.black,
          ),
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ),
);
Widget reservationImage(String? url, {double height = 160}) => ClipRRect(
  borderRadius: BorderRadius.circular(12),
  child: url == null || url.isEmpty
      ? SizedBox(
          height: height,
          child: const Center(
            child: Icon(
              Icons.event_seat_outlined,
              size: 40,
              color: reservationGold,
            ),
          ),
        )
      : url.startsWith('assets/')
      ? Image.asset(
          url,
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
        )
      : CachedMediaImage(
          url,
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => SizedBox(
            height: height,
            child: const Icon(
              Icons.event_seat_outlined,
              color: reservationGold,
            ),
          ),
        ),
);
Widget reservationScaffold(
  BuildContext context, {
  required String title,
  required Widget body,
  VoidCallback? onBack,
  List<Widget>? actions,
  Widget? bottom,
}) => GestureDetector(
  behavior: HitTestBehavior.translucent,
  onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
  child: Scaffold(
    backgroundColor: const Color(0xff111111),
    resizeToAvoidBottomInset: false,
    appBar: kingAppBar(
      context: context,
      title: Text(title),
      leading: onBack == null ? null : KingBackButton(onPressed: onBack),
      actions: actions,
      foregroundColor: Colors.white,
    ),
    body: body,
    bottomNavigationBar: bottom == null
        ? null
        : SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: bottom,
            ),
          ),
  ),
);
