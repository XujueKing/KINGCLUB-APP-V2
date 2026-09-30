BigInt balanceCents(Object? value) {
  if (value is! String || !RegExp(r'^(0|[1-9][0-9]{0,29})$').hasMatch(value)) {
    throw const FormatException('Invalid balance');
  }
  return BigInt.parse(value);
}

String balanceMoney(BigInt cents) =>
    '${cents ~/ BigInt.from(100)}.${(cents % BigInt.from(100)).toString().padLeft(2, '0')}';
Map<String, dynamic> _map(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Invalid balance snapshot');
  }
  return value;
}

String _text(Object? value, int max) {
  if (value is! String || value.length > max) {
    throw const FormatException('Invalid balance text');
  }
  return value;
}

class MemberBalanceLot {
  MemberBalanceLot(
    this.ref,
    this.principal,
    this.gift,
    this.expired,
    this.expires,
    this.rules,
  );
  final String ref, rules;
  final BigInt principal, gift;
  final bool expired;
  final DateTime? expires;
}

class MemberStoreBalance {
  MemberStoreBalance(
    this.ref,
    this.name,
    this.status,
    this.accountStatus,
    this.principal,
    this.gift,
    this.expiredGift,
    this.lots,
  );
  final String ref, name, status, accountStatus;
  final BigInt principal, gift, expiredGift;
  final List<MemberBalanceLot> lots;
}

class MemberBalanceSnapshot {
  MemberBalanceSnapshot._(this.platformCash, this.total, this.at, this.stores);
  final BigInt platformCash, total;
  final DateTime at;
  final List<MemberStoreBalance> stores;

  /// Earliest transition that can change this display-only total. The server
  /// snapshot clock, not the phone's wall clock, anchors the refresh deadline.
  DateTime? get nextGiftExpiry {
    DateTime? next;
    for (final store in stores) {
      for (final lot in store.lots) {
        final expiry = lot.expires;
        if (!lot.expired &&
            lot.gift > BigInt.zero &&
            expiry != null &&
            (next == null || expiry.isBefore(next))) {
          next = expiry;
        }
      }
    }
    return next;
  }

  factory MemberBalanceSnapshot.parse(Object? raw) {
    final root = _map(raw),
        platform = _map(root['platform']),
        summary = _map(root['summary']);
    if (root['currency'] != 'CNY' ||
        platform['accountType'] != 'platform_cash' ||
        summary['displayOnly'] != true ||
        root['stores'] is! List) {
      throw const FormatException('Invalid balance scope');
    }
    final at = DateTime.parse(_text(root['snapshotAt'], 40));
    final cash = balanceCents(platform['cashCents']);
    final stores = <MemberStoreBalance>[],
        seen = <String>{},
        seenLots = <String>{};
    var principal = BigInt.zero, gifts = BigInt.zero;
    final values = root['stores'] as List;
    if (values.length > 10000) {
      throw const FormatException('Balance snapshot too large');
    }
    for (final value in values) {
      final row = _map(value),
          ref = _text(row['storeRef'], 64),
          name = _text(row['storeName'], 128);
      if (!RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(ref) ||
          name.isEmpty ||
          !seen.add(ref) ||
          row['accountType'] != 'store_balance' ||
          !['active', 'closed', 'disabled'].contains(row['storeStatus']) ||
          !['active', 'frozen'].contains(row['accountStatus']) ||
          row['lots'] is! List) {
        throw const FormatException('Invalid store balance');
      }
      final p = balanceCents(row['principalCents']),
          g = balanceCents(row['giftCents']),
          e = balanceCents(row['expiredGiftCents']);
      if (balanceCents(row['displayTotalCents']) != p + g) {
        throw const FormatException('Store total mismatch');
      }
      final lots = <MemberBalanceLot>[];
      var lp = BigInt.zero, lg = BigInt.zero, le = BigInt.zero;
      for (final item in row['lots'] as List) {
        final lot = _map(item), id = _text(lot['lotRef'], 36);
        if (!RegExp(
              r'^[a-f0-9]{8}-[a-f0-9]{4}-[1-5][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
            ).hasMatch(id) ||
            !seenLots.add(id) ||
            seenLots.length > 10000 ||
            lot['giftExpired'] is! bool) {
          throw const FormatException('Invalid recharge lot');
        }
        final expiry = lot['giftExpiresAt'] == null
            ? null
            : DateTime.parse(_text(lot['giftExpiresAt'], 40));
        final expired = lot['giftExpired'] as bool;
        if (expired != (expiry != null && !expiry.isAfter(at))) {
          throw const FormatException('Gift expiry mismatch');
        }
        final lotPrincipal = balanceCents(lot['principalCents']),
            lotGift = balanceCents(lot['giftCents']);
        lp += lotPrincipal;
        if (expired) {
          le += lotGift;
        } else {
          lg += lotGift;
        }
        lots.add(
          MemberBalanceLot(
            id,
            lotPrincipal,
            lotGift,
            expired,
            expiry,
            _text(lot['rulesDescription'], 4000),
          ),
        );
      }
      if (lp != p || lg != g || le != e) {
        throw const FormatException('Recharge lot sum mismatch');
      }
      principal += p;
      gifts += g;
      stores.add(
        MemberStoreBalance(
          ref,
          name,
          row['storeStatus'] as String,
          row['accountStatus'] as String,
          p,
          g,
          e,
          List.unmodifiable(lots),
        ),
      );
    }
    final total = balanceCents(summary['displayTotalCents']);
    if (balanceCents(summary['platformCashCents']) != cash ||
        balanceCents(summary['storePrincipalCents']) != principal ||
        balanceCents(summary['storeGiftCents']) != gifts ||
        total != cash + principal + gifts) {
      throw const FormatException('Balance total mismatch');
    }
    return MemberBalanceSnapshot._(cash, total, at, List.unmodifiable(stores));
  }
}
