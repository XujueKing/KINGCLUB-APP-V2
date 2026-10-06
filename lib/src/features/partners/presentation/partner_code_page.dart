import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/design_system/king_components.dart';
import '../../../core/session/secure_session_store.dart';
import '../data/partner_repository.dart';
import 'partner_strings.dart';

/// A referral code never authorizes payment or automatically grants a reward.
class PartnerCodePage extends StatefulWidget {
  const PartnerCodePage({super.key, this.code, this.call});
  final String? code;
  final PartnerCall? call;
  @override
  State<PartnerCodePage> createState() => _PartnerCodePageState();
}

class _PartnerCodePageState extends State<PartnerCodePage> {
  late final call = widget.call ?? PartnerRepository().call;
  Map<String, dynamic>? data;
  bool busy = false, failed = false, invalid = false;
  Timer? expiry;
  StreamSubscription<void>? session;
  String t(String key) => partnerText(context, key);
  @override
  void initState() {
    super.initState();
    session = SecureSessionStore.changes.stream.listen((_) {
      expiry?.cancel();
      if (mounted) {
        setState(() {
          invalid = true;
          data = null;
        });
      }
    });
    load(widget.code == null ? 'code' : 'preview');
  }

  Future<void> load(String action) async {
    if (busy || invalid) return;
    expiry?.cancel();
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      final result = await call({
        'action': action,
        if (widget.code != null) 'code': widget.code,
      });
      if (!mounted || invalid) return;
      if (widget.code == null) {
        if (!RegExp(r'^KC:P:[0-9A-F]{32}$')
                .hasMatch(result['code'] as String? ?? '') ||
            result['ttlSeconds'] != 600) {
          throw const FormatException('Invalid referral code');
        }
        expiry = Timer(const Duration(minutes: 10), () {
          if (mounted) {
            setState(() {
              data = null;
              failed = true;
            });
          }
        });
      }
      setState(() => data = result);
    } catch (_) {
      if (mounted && !invalid) {
        setState(() {
          failed = true;
          if (widget.code == null) data = null;
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    expiry?.cancel();
    session?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bound = data?['bound'] == true || data?['bound'] == 1;
    return Scaffold(
      backgroundColor: const Color(0xff111111),
      appBar: kingAppBar(
        context: context,
        centerTitle: true,
        title: Text(
          t('code'),
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              if (busy) const Center(child: CircularProgressIndicator()),
              if (invalid)
                Text(t('sessionChanged'), textAlign: TextAlign.center),
              if (!invalid && data != null) ...[
                if (widget.code == null)
                  Center(
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(16),
                      child: QrImageView(
                        data: data!['code'] as String,
                        size: (MediaQuery.sizeOf(context).width - 100)
                            .clamp(120, 280)
                            .toDouble(),
                      ),
                    ),
                  )
                else ...[
                  Icon(
                    bound
                        ? Icons.check_circle_outline
                        : Icons.handshake_outlined,
                    color: Colors.white,
                    size: 72,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    bound ? t('bound') : data!['name'] as String? ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  t(widget.code == null ? 'codeHint' : 'bindHint'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, height: 1.6),
                ),
              ],
              if (failed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(t('codeFailed'), textAlign: TextAlign.center),
                ),
              const SizedBox(height: 32),
              if (!invalid)
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: busy
                        ? null
                        : () {
                            if (bound) {
                              Navigator.pop(context);
                            } else {
                              load(
                                widget.code == null
                                    ? 'code'
                                    : data == null
                                    ? 'preview'
                                    : 'bind',
                              );
                            }
                          },
                    child: Text(
                      t(
                        bound
                            ? 'done'
                            : widget.code == null
                            ? 'refreshCode'
                            : data == null
                            ? 'retry'
                            : 'bind',
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
