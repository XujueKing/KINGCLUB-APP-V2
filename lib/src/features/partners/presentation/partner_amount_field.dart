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
  if (!RegExp(r'^\d+(\.\d{0,2})?$').hasMatch(text)) return null;
  final parts = text.split('.');
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
    if (!RegExp(r'^\d*(\.\d{0,2})?$').hasMatch(newValue.text)) return oldValue;
    if ((partnerAmountCents(newValue.text) ?? 0) <= limit) return newValue;
    final capped = moneyCents(limit).replaceAll(',', '');
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
    controller: controller,
    enabled: enabled && limit > 0,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    textInputAction: TextInputAction.done,
    onSubmitted: (_) => FocusScope.of(context).unfocus(),
    inputFormatters: [PartnerAmountFormatter(limit)],
    style: const TextStyle(fontSize: 24, color: Colors.white),
    decoration: InputDecoration(
      labelText: label,
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
                controller.text = moneyCents(limit).replaceAll(',', '');
                controller.selection = TextSelection.collapsed(
                  offset: controller.text.length,
                );
              },
        child: Text(partnerText(context, 'amountMax')),
      ),
    ),
  );
}
