import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/formatters/money.dart';
import 'partner_strings.dart';

int partnerAmountLimit(Object? available) {
  final value = BigInt.tryParse('$available') ?? BigInt.zero;
  if (value.isNegative) return 0;
  return value > BigInt.from(999999999) ? 999999999 : value.toInt();
}

int? partnerAmountCents(String text) {
  if (!RegExp(r'^(\d+|\d{1,3}(,\d{3})+)(\.\d{0,2})?$').hasMatch(text)) {
    return null;
  }
  final parts = text.replaceAll(',', '').split('.');
  final cents =
      BigInt.parse(parts[0]) * BigInt.from(100) +
      (parts.length == 1 || parts[1].isEmpty
          ? BigInt.zero
          : BigInt.parse(parts[1].padRight(2, '0')));
  return cents > BigInt.from(999999999) ? 1000000000 : cents.toInt();
}

class PartnerAmountFormatter extends TextInputFormatter {
  PartnerAmountFormatter(this.limit);
  final int limit;
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.replaceAll(',', '');
    if (!RegExp(r'^\d*(\.\d{0,2})?$').hasMatch(raw)) return oldValue;
    if ((partnerAmountCents(raw) ?? 0) <= limit) {
      final parts = raw.split('.');
      final grouped = parts[0].replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'),
        (match) => '${match[1]},',
      );
      final text = '$grouped${parts.length > 1 ? '.${parts[1]}' : ''}';
      int offset(int original) {
        if (original < 0) return text.length;
        final logical = newValue.text
            .substring(0, original)
            .replaceAll(',', '')
            .length;
        var count = 0;
        var position = 0;
        while (position < text.length && count < logical) {
          if (text[position] != ',') count++;
          position++;
        }
        return position;
      }

      return TextEditingValue(
        text: text,
        selection: TextSelection(
          baseOffset: offset(newValue.selection.baseOffset),
          extentOffset: offset(newValue.selection.extentOffset),
        ),
      );
    }
    final capped = moneyCents(limit);
    return TextEditingValue(
      text: capped,
      selection: TextSelection.collapsed(offset: capped.length),
    );
  }
}

class PartnerAmountField extends StatelessWidget {
  const PartnerAmountField({
    super.key,
    required this.controller,
    required this.limit,
    required this.label,
    required this.enabled,
  });
  final TextEditingController controller;
  final int limit;
  final String label;
  final bool enabled;
  @override
  Widget build(BuildContext context) => TextField(
    key: const ValueKey('partner-amount-input'),
    controller: controller,
    enabled: enabled && limit > 0,
    selectAllOnFocus: true,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    textInputAction: TextInputAction.done,
    onSubmitted: (_) => FocusScope.of(context).unfocus(),
    inputFormatters: [PartnerAmountFormatter(limit)],
    style: const TextStyle(fontSize: 24, color: Colors.white),
    decoration: InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      hintText: '0.00',
      prefixText: '¥ ',
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      filled: true,
      fillColor: const Color(0xff202020),
      contentPadding: const EdgeInsets.all(18),
      suffixIcon: TextButton(
        key: const ValueKey('partner-amount-max'),
        onPressed: !enabled || limit <= 0
            ? null
            : () {
                controller.text = moneyCents(limit);
                controller.selection = TextSelection.collapsed(
                  offset: controller.text.length,
                );
              },
        child: Text(partnerText(context, 'amountMax')),
      ),
    ),
  );
}
