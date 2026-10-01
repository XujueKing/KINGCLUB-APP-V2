import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/session/secure_session_store.dart';
import '../data/store_payment_availability_repository.dart';

/// Hidden until this store's authenticated configuration is explicitly ready.
class StoreAlipayPaymentOption extends StatefulWidget {
  const StoreAlipayPaymentOption({
    super.key,
    required this.storeRef,
    required this.repository,
    required this.selected,
    required this.onTap,
    required this.label,
    required this.unit,
    this.onUnavailable,
  });
  final String storeRef, label;
  final StorePaymentAvailabilityRepository repository;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onUnavailable;
  final double unit;
  @override
  State<StoreAlipayPaymentOption> createState() =>
      _StoreAlipayPaymentOptionState();
}

class _StoreAlipayPaymentOptionState extends State<StoreAlipayPaymentOption>
    with WidgetsBindingObserver {
  bool _available = false;
  int _generation = 0;
  StreamSubscription<void>? _session;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _session = SecureSessionStore.changes.stream.listen((_) {
      _generation++;
      if (mounted) setState(() => _available = false);
    });
    unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_generation;
    if (mounted) setState(() => _available = false);
    var available = false;
    try {
      available = await widget.repository.alipayAvailable(widget.storeRef);
    } catch (_) {}
    if (mounted && generation == _generation) {
      setState(() => _available = available);
      if (!available) widget.onUnavailable?.call();
    }
  }

  @override
  void didUpdateWidget(covariant StoreAlipayPaymentOption oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storeRef != widget.storeRef) unawaited(_load());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_load());
  }

  @override
  void dispose() {
    _generation++;
    _session?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) return const SizedBox.shrink();
    final u = widget.unit;
    return Padding(
      padding: EdgeInsets.only(top: 24 * u),
      child: InkWell(
        key: const ValueKey('payment-provider-alipay'),
        onTap: widget.onTap,
        child: Row(
          children: [
            Image.asset(
              'assets/legacy/payment/legacy_alipay.png',
              width: 44 * u,
              height: 44 * u,
            ),
            SizedBox(width: 15 * u),
            Expanded(child: Text(widget.label)),
            Icon(
              widget.selected
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: const Color(0xFF55493C),
              size: 36 * u,
            ),
          ],
        ),
      ),
    );
  }
}
