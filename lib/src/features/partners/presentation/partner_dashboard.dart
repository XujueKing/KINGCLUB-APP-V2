import 'package:flutter/material.dart';

import '../../../core/design_system/king_control_sizes.dart';
import '../../../core/media/cached_media_image.dart';
import '../../../core/formatters/money.dart';
import '../../../core/session/member_qr_memory.dart';
import '../../profile_settings/presentation/profile_image_ref.dart';
import '../../auth/data/auth_repository_provider.dart';
import '../data/partner_repository.dart';
import 'partner_strings.dart';

const _gold = Color(0xffcebea4);

class PartnerIdentityHeader extends StatelessWidget {
  const PartnerIdentityHeader({
    super.key,
    required this.data,
    this.avatarPath,
    this.onIdentity,
  });
  final PartnerContext data;
  final String? avatarPath;
  final VoidCallback? onIdentity;
  @override
  Widget build(BuildContext context) {
    final avatar = data.profile['avatar'] as Map?;
    final path = avatar?['path'] as String?;
    final localAvatar = avatarPath ?? MemberQrMemory.avatar?.path;
    final fallback = const ColoredBox(
      color: Color(0xff302a21),
      child: Icon(Icons.person_outline, color: _gold),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: 68,
              height: 68,
              child: localAvatar != null
                  ? Image(
                      image: profileImageProvider(localAvatar),
                      fit: BoxFit.cover,
                    )
                  : path == null
                  ? fallback
                  : CachedMediaImage(
                      Uri.parse(kingclubApiBaseUrl).resolve(path).toString(),
                      private: true,
                      contentKey: avatar?['fileId'] == null
                          ? null
                          : 'profile:${avatar!['fileId']}',
                      placeholder: fallback,
                      errorBuilder: (_, _, _) => fallback,
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      data.profile['name'] as String? ??
                          partnerText(context, 'collaborator'),
                      style: const TextStyle(color: Colors.white, fontSize: 20),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xff302a21),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        partnerText(context, 'collaborator'),
                        style: const TextStyle(color: _gold, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${partnerText(context, 'referrerLevel')} L${data.partner!['level']}',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          if (onIdentity != null)
            IconButton(
              onPressed: onIdentity,
              tooltip: partnerText(context, 'code'),
              icon: const Icon(Icons.chevron_right, color: Colors.white60),
            ),
        ],
      ),
    );
  }
}

class PartnerEarningsCard extends StatelessWidget {
  const PartnerEarningsCard({
    super.key,
    required this.data,
    required this.onWithdraw,
    required this.onTransfer,
  });
  final PartnerContext data;
  final VoidCallback onWithdraw, onTransfer;
  String money(Object? v) => v == null ? '—' : '¥${moneyCents(v)}';
  @override
  Widget build(BuildContext context) {
    final finance = data.finance;
    final enabled = data.partner?['status'] == 'active' && finance != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${partnerText(context, 'monthlyEarnings')} · ${finance?['currency'] ?? 'CNY'}',
          style: const TextStyle(fontSize: 16, color: Colors.white60),
        ),
        const SizedBox(height: 14),
        Text(
          money(finance?['monthlyCents']),
          style: const TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            for (final field in [
              ('availableCents', 'withdrawAvailableShort'),
              ('pendingCents', 'pendingShort'),
            ])
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      partnerText(context, field.$2),
                      style: TextStyle(
                        fontFamily: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.fontFamily,
                        fontSize: 15,
                        color: Colors.white60,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      money(finance?[field.$1]),
                      style: const TextStyle(fontSize: 21, color: Colors.white),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            for (final action in [
              ('withdraw', onWithdraw, true),
              ('transfer', onTransfer, false),
            ]) ...[
              if (!action.$3) const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: kingControlHeight,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: action.$3
                          ? _gold
                          : const Color(0xff333333),
                      foregroundColor: action.$3 ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: const StadiumBorder(),
                    ),
                    onPressed: enabled ? action.$2 : null,
                    child: Text(
                      partnerText(context, action.$1),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (finance == null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              partnerText(context, 'financePending'),
              style: const TextStyle(color: Colors.white60),
            ),
          ),
      ],
    );
  }
}

class PartnerFeatureTile extends StatelessWidget {
  const PartnerFeatureTile({
    super.key,
    required this.label,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });
  final String label, subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xff202020),
    borderRadius: BorderRadius.circular(14),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: _gold, size: 28),
            const SizedBox(height: 18),
            Text(
              label,
              style: const TextStyle(fontSize: 19, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white60,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
