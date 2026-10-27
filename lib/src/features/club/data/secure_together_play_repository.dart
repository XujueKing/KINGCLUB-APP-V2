import 'dart:convert';
import 'dart:typed_data';

import 'together_rule_summary.dart';
import '../../../core/networking/kingclub_secure_client.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/domain/auth_repository.dart';
import '../../commerce/data/ordering_table_repository.dart';
import 'together_play.dart';
import 'together_feed.dart';

class TogetherCoupon {
  const TogetherCoupon({
    required this.ref,
    required this.name,
    required this.discountMinor,
  });
  final String ref, name;
  final int discountMinor;
}

class TogetherWechatResult {
  const TogetherWechatResult(this.status, this.payment);
  final String status;
  final Map<String, String>? payment;
}

class TogetherBooking {
  const TogetherBooking({
    required this.ref,
    required this.partyRef,
    required this.status,
    required this.basePriceMinor,
    required this.ageSurchargeMinor,
    required this.payableMinor,
  });
  final String ref, partyRef, status;
  final int basePriceMinor, ageSurchargeMinor, payableMinor;
}

/// The catalogue contains published invitations, not payment confirmations.
class SecureTogetherPlayRepository
    implements
        TogetherPlayRepository,
        TogetherFeedRepository,
        TogetherAdmissionRepository,
        TogetherRemovalRepository {
  SecureTogetherPlayRepository({
    required this.readSession,
    required this.request,
  });
  factory SecureTogetherPlayRepository.secure(String baseUrl) {
    final client = KingclubSecureClient(baseUrl);
    final sessions = SecureSessionStore();
    return SecureTogetherPlayRepository(
      readSession: sessions.readSession,
      request: (id, params, session) =>
          client.call(id, params, session: session),
    );
  }
  final OrderingSessionReader readSession;
  final OrderingContextRequest request;

  Never _invalid() =>
      throw const AuthFailure('TOGETHER_RESPONSE_INVALID', '活动信息暂不可用');
  String _text(dynamic v) {
    if (v is! String) _invalid();
    return v;
  }

  String _ref(dynamic v) {
    final s = _text(v);
    if (!RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(s)) _invalid();
    return s;
  }

  int _money(dynamic v) {
    final s = _text(v);
    if (!RegExp(r'^(0|[1-9][0-9]{0,17})$').hasMatch(s)) _invalid();
    final n = int.tryParse(s);
    if (n == null || n > 9007199254740991) _invalid();
    return n;
  }

  String _identity(Map<String, dynamic>? s) {
    final a = s?['account'];
    final parts = [
      a is Map ? a['userAccount'] : null,
      s?['sessionId'],
      s?['apiKeyId'],
      s?['apiKey'],
    ];
    if (parts.any((v) => v is! String || v.isEmpty)) {
      throw const AuthFailure('SESSION_EXPIRED', '请重新登录');
    }
    return parts.join('\u0000');
  }

  Future<Map> _call(
    String id,
    Map<String, dynamic> params,
    Map<String, dynamic> session,
    String identity,
  ) async {
    final response = await request(id, params, session);
    if (_identity(await readSession()) != identity) {
      throw const AuthFailure('SESSION_EXPIRED', '登录状态已变化');
    }
    final result = response['result'];
    if (result is! Map) _invalid();
    return result;
  }

  DateTime _date(dynamic v) {
    final s = _text(v);
    final date = DateTime.tryParse(s);
    if (date == null || !s.endsWith('Z')) _invalid();
    return date;
  }

  String _media(dynamic v) {
    final s = _text(v);
    final uri = Uri.tryParse(s);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      _invalid();
    }
    return s;
  }

  List<TogetherParticipant> _participants(dynamic value, int capacity) {
    if (value == null) return const [];
    if (value is! List || value.length > capacity) _invalid();
    final used = <int>{};
    return value.map<TogetherParticipant>((dynamic item) {
      if (item is! Map) _invalid();
      final index = item['seatIndex'];
      final photo = item['avatarBase64'];
      if (index is! int ||
          index < 0 ||
          index >= capacity ||
          !used.add(index) ||
          ![0, 1, 2].contains(item['gender']) ||
          (photo != null && (photo is! String || photo.length > 65536))) {
        _invalid();
      }
      return TogetherParticipant(
        name: _text(item['name']),
        account: item['account'] == null ? null : _ref(item['account']),
        tableRef: item['tableRef'] == null ? null : _ref(item['tableRef']),
        seatIndex: index,
        gender: switch (item['gender']) {
          1 => TogetherGender.male,
          2 => TogetherGender.female,
          _ => TogetherGender.unspecified,
        },
        avatarBytes: photo == null ? null : base64Decode(photo as String),
        isMe: item['isMe'] == true,
      );
    }).toList();
  }

  Uint8List? _hostAvatar(dynamic value) {
    if (value == null) return null;
    if (value is! String || value.length > 65536) _invalid();
    return base64Decode(value);
  }

  List<TogetherActivityTable> _tables(dynamic value) {
    if (value == null) return const [];
    if (value is! List || value.length > 30) _invalid();
    final refs = <String>{};
    return value.map((dynamic t) {
      if (t is! Map) _invalid();
      final ref = _ref(t['ref']);
      final capacity = t['capacity'],
          male = t['maleSeats'],
          female = t['femaleSeats'];
      if (!refs.add(ref) ||
          capacity is! int ||
          capacity < 1 ||
          capacity > 100 ||
          male is! int ||
          male < 0 ||
          female is! int ||
          female < 0 ||
          male + female != capacity) {
        _invalid();
      }
      final people = _participants(t['participants'], capacity);
      final reserved = t['reservedSeats'] ?? <int>[];
      if (reserved is! List || reserved.length > capacity) _invalid();
      final used = people.map((p) => p.seatIndex!).toSet();
      final blocked = <int>[];
      for (final i in reserved) {
        if (i is! int || i < 0 || i >= capacity || !used.add(i)) _invalid();
        blocked.add(i);
      }
      if (people.any(
        (p) =>
            p.tableRef != ref ||
            t['genderRestricted'] != false &&
                p.gender !=
                    (p.seatIndex! < male
                        ? TogetherGender.male
                        : TogetherGender.female),
      )) {
        _invalid();
      }
      return TogetherActivityTable(
        ref: ref,
        name: _text(t['name']),
        capacity: capacity,
        maleSeats: male,
        femaleSeats: female,
        participants: people,
        reservedSeats: blocked,
        genderRestricted: t['genderRestricted'] != false,
      );
    }).toList();
  }

  TogetherParty _party(dynamic value, {bool detail = false}) {
    if (value is! Map) _invalid();
    final r = value;
    final confirmed = r['confirmedCount'];
    final bookingStatus = r['myBookingStatus'];
    if (confirmed is! int ||
        confirmed < 0 ||
        ![
          null,
          'pending',
          'paying',
          'paid',
          'cancelled',
          'refunded',
        ].contains(bookingStatus)) {
      _invalid();
    }
    final start = _date(r['startsAt']), end = _date(r['endsAt']);
    final capacity = r['capacity'];
    if (capacity is! int ||
        capacity < 2 ||
        capacity > 65535 ||
        !end.isAfter(start)) {
      _invalid();
    }
    final fee = switch (r['feeMode']) {
      'aa' => TogetherFeeMode.aa,
      'men_pay' => TogetherFeeMode.menPay,
      'host_treat' => TogetherFeeMode.hostTreat,
      _ => _invalid(),
    };
    final posters = r['posterUrls'];
    if (posters != null &&
        (posters is! List || posters.isEmpty || posters.length > 3)) {
      _invalid();
    }
    final eligibility = r['eligibility'];
    if (detail && eligibility is! Map) _invalid();
    bool? eligible;
    List<String> reasons = [];
    int? personalPrice;
    if (eligibility != null) {
      if (eligibility is! Map ||
          eligibility['eligible'] is! bool ||
          eligibility['reasons'] is! List) {
        _invalid();
      }
      eligible = eligibility['eligible'] as bool;
      reasons = (eligibility['reasons'] as List).map(_text).toList();
      if (eligible) {
        personalPrice = _money(eligibility['payableCents']);
        if (reasons.isNotEmpty) _invalid();
      } else if (reasons.isEmpty || eligibility['payableCents'] != null) {
        _invalid();
      }
    }
    final genders = <TogetherGender>[];
    final pricing = r['genderPricing'];
    if (pricing != null) {
      if (pricing is! Map) _invalid();
      final male = pricing['maleSeats'], female = pricing['femaleSeats'];
      if (male is! int ||
          female is! int ||
          male < 0 ||
          female < 0 ||
          male + female != capacity) {
        _invalid();
      }
      genders.addAll(List.filled(male, TogetherGender.male));
      genders.addAll(List.filled(female, TogetherGender.female));
    }
    // Display venue time consistently even when the phone is abroad.
    DateTime venue(DateTime utc) {
      final d = utc.add(const Duration(hours: 8));
      return DateTime(d.year, d.month, d.day, d.hour, d.minute, d.second);
    }

    return TogetherParty(
      ref: _ref(r['ref']),
      theme: _text(r['theme']),
      cityCode: _ref(r['cityCode']),
      cityName: '',
      storeRef: _ref(r['storeRef']),
      storeName: _text(r['storeName']),
      storeLogo: r['storeLogo'] == null ? null : _media(r['storeLogo']),
      hostAvatar: r['hostAvatar'] == null ? null : _media(r['hostAvatar']),
      hostAvatarBytes: _hostAvatar(r['hostAvatarBase64']),
      seatRequests: r['seatRequests'] is List
          ? (r['seatRequests'] as List)
                .map((dynamic v) => Map<String, dynamic>.from(v as Map))
                .toList()
          : const [],
      hostIntroduction: r['hostIntroduction'] is String
          ? r['hostIntroduction'] as String
          : '',
      cardKicker: r['cardKicker'] == null ? null : _text(r['cardKicker']),
      cardPublisher: r['cardPublisher'] == null
          ? null
          : (const ['store', 'member'].contains(r['cardPublisher'])
                ? r['cardPublisher'] as String
                : _invalid()),
      myGender: r['myGender'] == 1
          ? TogetherGender.male
          : r['myGender'] == 2
          ? TogetherGender.female
          : TogetherGender.unspecified,
      seatChangePending: r['seatChangePending'] == true,
      tables: _tables(r['tables']),
      startsAt: venue(start),
      endsAt: venue(end),
      hostName: r['publisherType'] == 'official'
          ? _text(r['storeName'])
          : r['hostName'] == null
          ? '会员'
          : _text(r['hostName']),
      merchantHost: r['publisherType'] == 'official',
      collaboratorHost: r['publisherType'] == 'collaborator',
      allowCoins: r['allowCoins'] == true,
      place: _text(r['place']),
      capacity: capacity,
      participants: _participants(r['participants'], capacity),
      confirmedCount: confirmed,
      ticketNumber: bookingStatus == 'paid' && r['ticketNumber'] != null
          ? _ref(r['ticketNumber'])
          : null,
      assignedTable:
          (bookingStatus == 'paid' || r['publisherType'] == 'collaborator') &&
              r['assignedTable'] != null
          ? _text(r['assignedTable'])
          : null,
      admissionUsed: bookingStatus == 'paid' && r['admissionUsed'] == true,
      bookingStatus: bookingStatus as String?,
      bookingRef: r['myBookingRef'] == null ? null : _ref(r['myBookingRef']),
      bookingPayableMinor: r['myPayableCents'] == null
          ? null
          : _money(r['myPayableCents']),
      feeMode: fee,
      priceMinor: _money(r['priceCents']),
      state: r['partyStatus'] == 'cancelled'
          ? TogetherJoinState.cancelled
          : bookingStatus == 'paid'
          ? TogetherJoinState.joined
          : !end.isAfter(DateTime.now().toUtc())
          ? TogetherJoinState.closed
          : bookingStatus == 'pending' || bookingStatus == 'paying'
          ? TogetherJoinState.pendingPayment
          : bookingStatus == 'cancelled' || bookingStatus == 'refunded'
          ? TogetherJoinState.cancelled
          : TogetherJoinState.available,
      description: _text(r['description']),
      rules: r['eligibilityRules'] == null
          ? ''
          : r['eligibilityRules'] is Map
          ? togetherRuleSummary(r['eligibilityRules'] as Map)
          : _invalid(),
      backgroundUrl: _media(r['backgroundUrl']),
      posterUrl: _media(r['posterUrl']),
      posterUrls: posters == null
          ? const []
          : (posters as List).map(_media).toList(),
      seatGenders: genders,
      eligible: eligible,
      eligibilityReasons: reasons,
      personalPriceMinor: personalPrice,
    );
  }

  @override
  Future<TogetherFeedPage> feed({
    required TogetherFeedView view,
    String? cityCode,
    String? storeRef,
    DateTime? date,
    String? after,
  }) async {
    if (view == TogetherFeedView.recommendations && cityCode == null) {
      _invalid();
    }
    if (cityCode != null) _ref(cityCode);
    if (storeRef != null) _ref(storeRef);
    if (after != null) _ref(after);
    final session = await readSession();
    final identity = _identity(session);
    final day = date == null
        ? null
        : '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final r = await _call(
      'K261004001985',
      {
        'view': view.name,
        'cityCode': ?cityCode,
        'storeRef': ?storeRef,
        'date': ?day,
        'after': ?after,
        'limit': 20,
      },
      session!,
      identity,
    );
    if (r['view'] != view.name ||
        r['cityCode'] != cityCode ||
        r['storeRef'] != storeRef ||
        r['date'] != day ||
        r['items'] is! List) {
      _invalid();
    }
    final rows = r['items'] as List;
    if (rows.length > 20) _invalid();
    final seen = <String>{};
    final items = rows.map(_party).toList();
    for (final p in items) {
      if (!seen.add(p.ref) ||
          (cityCode != null && p.cityCode != cityCode) ||
          (storeRef != null && p.storeRef != storeRef) ||
          (date != null &&
              (p.startsAt.year != date.year ||
                  p.startsAt.month != date.month ||
                  p.startsAt.day != date.day))) {
        _invalid();
      }
      if (view == TogetherFeedView.tickets &&
          (!p.hasAdmissionTicket || p.admissionUsed)) {
        _invalid();
      }
    }
    final next = r['next'];
    if (next != null &&
        (items.isEmpty || _ref(next) != items.last.ref || next == after)) {
      _invalid();
    }
    final viewer = r['viewer'];
    Uint8List? avatar;
    if (viewer is Map && viewer['avatarBase64'] != null) {
      final image = viewer['avatarBase64'];
      if (image is! String || image.length > 65536) _invalid();
      avatar = base64Decode(image);
    }
    return TogetherFeedPage(items, next as String?, avatarBytes: avatar);
  }

  @override
  Future<List<TogetherParty>> list({
    required String cityCode,
    required DateTime date,
  }) async {
    _ref(cityCode);
    final from = DateTime.utc(
      date.year,
      date.month,
      date.day,
    ).subtract(const Duration(hours: 8));
    final before = from.add(const Duration(days: 1));
    final session = await readSession();
    final identity = _identity(session);
    String? after;
    final items = <TogetherParty>[];
    final seen = <String>{};
    do {
      final result = await _call(
        'K261004001985',
        {
          'cityCode': cityCode,
          'startsFrom': from.toIso8601String(),
          'startsBefore': before.toIso8601String(),
          'limit': 100,
          'after': ?after,
        },
        session!,
        identity,
      );
      if (result['cityCode'] != cityCode ||
          _date(result['startsFrom']) != from ||
          _date(result['startsBefore']) != before ||
          result['items'] is! List) {
        _invalid();
      }
      final page = result['items'] as List;
      if (page.length > 100) _invalid();
      for (final row in page) {
        final p = _party(row);
        final start = _date((row as Map)['startsAt']);
        if (p.cityCode != cityCode ||
            start.isBefore(from) ||
            !start.isBefore(before) ||
            !seen.add(p.ref)) {
          _invalid();
        }
        items.add(p);
      }
      final next = result['next'];
      if (next != null &&
          (page.isEmpty ||
              _ref(next) != (page.last as Map)['ref'] ||
              next == after)) {
        _invalid();
      }
      after = next as String?;
    } while (after != null);
    return items;
  }

  @override
  Future<TogetherParty> detail(String ref) async {
    _ref(ref);
    final session = await readSession();
    final identity = _identity(session);
    final result = await _call(
      'K261004001986',
      {'partyRef': ref},
      session!,
      identity,
    );
    final party = _party(result['item'], detail: true);
    if (party.ref != ref) _invalid();
    return party;
  }

  @override
  Future<TogetherParty> admission(String ref) async {
    final session = await readSession();
    final identity = _identity(session);
    final party = await detail(ref);
    if (_identity(await readSession()) != identity) {
      throw const AuthFailure('SESSION_EXPIRED', '登录状态已变化');
    }
    if (!party.hasAdmissionTicket) {
      throw const AuthFailure('TOGETHER_PAID_ADMISSION_REQUIRED', '请先完成报名付款');
    }
    if (party.admissionUsed) return party;
    final result = await _call(
      'K261004001989',
      {'partyRef': ref},
      session!,
      identity,
    );
    final number = _ref(result['ticketNumber']);
    if (party.ticketNumber != null && number != party.ticketNumber) _invalid();
    final code = _text(result['admissionCode']);
    final expires = _date(result['expiresAt']);
    if (result['partyRef'] != ref ||
        !RegExp(r'^KCTICKET1:[A-Za-z0-9_-]{43}$').hasMatch(code) ||
        !expires.isAfter(DateTime.now().toUtc())) {
      _invalid();
    }
    return party.withAdmission(
      number: _ref(result['ticketNumber']),
      code: code,
      expiresAt: expires,
    );
  }

  Future<Map> _removal(Map<String, dynamic> params) async {
    final session = await readSession();
    final identity = _identity(session);
    return _call('K261004001993', params, session!, identity);
  }

  @override
  Future<TogetherRemovalMembers> removalMembers(
    String partyRef, {
    String? after,
  }) async {
    final r = await _removal({
      'action': 'list',
      'partyRef': partyRef,
      'after': ?after,
    });
    if (r['partyRef'] != partyRef ||
        r['canManage'] is! bool ||
        r['items'] is! List) {
      _invalid();
    }
    final items = <TogetherRemovalMember>[];
    for (final item in r['items'] as List) {
      if (item is! Map || item['admitted'] is! bool) {
        _invalid();
      }
      items.add(
        TogetherRemovalMember(
          _ref(item['bookingRef']),
          _text(item['name']),
          item['admitted'] as bool,
        ),
      );
    }
    if (items.map((m) => m.bookingRef).toSet().length != items.length) {
      _invalid();
    }
    return TogetherRemovalMembers(
      r['canManage'] as bool,
      items,
      r['next'] == null ? null : _ref(r['next']),
    );
  }

  @override
  Future<TogetherRemovalQuote> removalQuote(
    String partyRef,
    String bookingRef,
  ) async {
    final r = await _removal({
      'action': 'quote',
      'partyRef': partyRef,
      'bookingRef': bookingRef,
    });
    if (r['partyRef'] != partyRef ||
        r['bookingRef'] != bookingRef ||
        r['currency'] != 'CNY' ||
        r['methods'] is! List) {
      _invalid();
    }
    final refund = _money(r['refundCents']),
        participant = _money(r['participantCompensationCents']),
        merchant = _money(r['merchantCompensationCents']),
        total = _money(r['totalCents']);
    final methods = (r['methods'] as List).map((v) => _text(v)).toList();
    if (total != refund + participant + merchant ||
        methods.isEmpty ||
        methods.any((v) => !['platform_cash', 'wechat'].contains(v))) {
      _invalid();
    }
    return TogetherRemovalQuote(
      bookingRef,
      refund,
      participant,
      merchant,
      total,
      methods,
    );
  }

  @override
  Future<void> payRemoval(
    String partyRef,
    TogetherRemovalQuote quote, {
    required String requestRef,
    required String method,
  }) async {
    final r = await _removal({
      'action': 'pay',
      'partyRef': partyRef,
      'bookingRef': quote.bookingRef,
      'requestRef': requestRef,
      'expectedCents': quote.totalMinor.toString(),
      'method': method,
    });
    if (r['partyRef'] != partyRef ||
        r['bookingRef'] != quote.bookingRef ||
        r['refundRef'] != requestRef ||
        r['removal'] is! Map ||
        r['replayed'] is! bool) {
      _invalid();
    }
    final removal = r['removal'] as Map;
    if (_money(removal['payerCents']) != quote.totalMinor ||
        _money(removal['participantCompensationCents']) !=
            quote.participantCompensationMinor ||
        _money(removal['merchantCompensationCents']) !=
            quote.merchantCompensationMinor) {
      _invalid();
    }
  }

  Future<List<TogetherCoupon>> coupons(
    TogetherBooking booking,
    String storeRef,
  ) async {
    final session = await readSession();
    final identity = _identity(session);
    final result = await _call(
      'K261004001992',
      {'bookingRef': booking.ref},
      session!,
      identity,
    );
    if (result['bookingRef'] != booking.ref ||
        result['storeRef'] != storeRef ||
        result['items'] is! List) {
      _invalid();
    }
    final items = <TogetherCoupon>[];
    for (final raw in result['items'] as List) {
      if (raw is! Map) _invalid();
      final amount = _money(raw['discountCents']);
      if (amount <= 0 || amount > booking.payableMinor) _invalid();
      items.add(
        TogetherCoupon(
          ref: _ref(raw['itemRef']),
          name: _text(raw['name']),
          discountMinor: amount,
        ),
      );
    }
    if (items.map((c) => c.ref).toSet().length != items.length) _invalid();
    return items;
  }

  Future<TogetherWechatResult> wechatBooking(
    TogetherBooking booking, {
    required String action,
    required String storeRef,
    int coins = 0,
    TogetherCoupon? coupon,
  }) async {
    if (!['prepare', 'query', 'cancel'].contains(action) || coins < 0) {
      _invalid();
    }
    final session = await readSession();
    final identity = _identity(session);
    final result = await _call(
      'K261004001995',
      {
        'action': action,
        'bookingRef': booking.ref,
        if (action == 'prepare') ...{
          'expectedCents': booking.payableMinor.toString(),
          'coins': coins.toString(),
          if (coupon != null)
            'coupon': {
              'itemRef': coupon.ref,
              'expectedDiscountCents': coupon.discountMinor.toString(),
            },
        },
      },
      session!,
      identity,
    );
    final status = result['status'];
    if (result['bookingRef'] != booking.ref ||
        ![
          'pending',
          'paying',
          'paid',
          'cancelled',
          'refunded',
        ].contains(status)) {
      _invalid();
    }
    if (status == 'paid') {
      final receipt = result['receipt'];
      if (receipt is! Map ||
          receipt['bookingRef'] != booking.ref ||
          receipt['partyRef'] != booking.partyRef ||
          receipt['storeRef'] != storeRef ||
          receipt['method'] != 'wechat' ||
          receipt['currency'] != 'CNY' ||
          _money(receipt['totalCents']) != booking.payableMinor) {
        _invalid();
      }
    }
    Map<String, String>? payment;
    if (result['payment'] != null) {
      final raw = result['payment'];
      if (status != 'paying' || raw is! Map) _invalid();
      payment = {};
      for (final key in [
        'appId',
        'partnerId',
        'prepayId',
        'packageValue',
        'nonceStr',
        'timeStamp',
        'sign',
      ]) {
        final value = raw[key];
        if (value is! String || value.isEmpty || value.length > 2048) {
          _invalid();
        }
        payment[key] = value;
      }
      if (payment['packageValue'] != 'Sign=WXPay' ||
          int.tryParse(payment['timeStamp']!) == null) {
        _invalid();
      }
    }
    return TogetherWechatResult(status as String, payment);
  }

  Future<TogetherBooking> payBooking(
    TogetherBooking booking, {
    required String method,
    required int coins,
    required String storeRef,
    TogetherCoupon? coupon,
  }) async {
    if (coins < 0 ||
        !['free', 'store_balance', 'platform_cash'].contains(method)) {
      _invalid();
    }
    final session = await readSession();
    final identity = _identity(session);
    final result = await _call(
      'K261004001991',
      {
        'bookingRef': booking.ref,
        'expectedCents': booking.payableMinor.toString(),
        'method': method,
        'coins': coins.toString(),
        if (coupon != null)
          'coupon': {
            'itemRef': coupon.ref,
            'expectedDiscountCents': coupon.discountMinor.toString(),
          },
      },
      session!,
      identity,
    );
    if (result['bookingRef'] != booking.ref ||
        result['paymentRef'] != booking.ref ||
        result['partyRef'] != booking.partyRef ||
        result['storeRef'] != storeRef ||
        result['currency'] != 'CNY' ||
        result['method'] != method ||
        _money(result['totalCents']) != booking.payableMinor ||
        _money(result['coinsUsed']) != coins ||
        _money(result['couponDiscountCents'] ?? '0') !=
            (coupon?.discountMinor ?? 0) ||
        (coupon != null &&
            (result['coupon'] is! Map ||
                result['coupon']['itemRef'] != coupon.ref)) ||
        result['replayed'] is! bool) {
      _invalid();
    }
    return TogetherBooking(
      ref: booking.ref,
      partyRef: booking.partyRef,
      status: 'paid',
      basePriceMinor: booking.basePriceMinor,
      ageSurchargeMinor: booking.ageSurchargeMinor,
      payableMinor: booking.payableMinor,
    );
  }

  Future<void> reviewSeatChange(
    String partyRef,
    String requestRef,
    bool approve,
  ) async {
    final session = await readSession();
    final identity = _identity(session);
    await _call(
      'K261004001986',
      {
        'partyRef': partyRef,
        'seatAction': 'review',
        'requestRef': requestRef,
        'decision': approve ? 'approve' : 'reject',
      },
      session!,
      identity,
    );
  }

  Future<void> requestSeatChange(
    String partyRef,
    TogetherSeatChoice choice,
    String reason,
    String requestRef,
  ) async {
    final session = await readSession();
    final identity = _identity(session);
    await _call(
      'K261004001986',
      {
        'partyRef': partyRef,
        'seatAction': 'requestChange',
        'seatChoice': choice.toJson(),
        'reason': reason,
        'requestRef': requestRef,
      },
      session!,
      identity,
    );
  }

  /// Creates/retrieves an unpaid booking. Never interprets creation as admission.
  Future<TogetherBooking> prepareBooking(
    String partyRef, {
    required String requestRef,
    TogetherSeatChoice? seatChoice,
  }) async {
    _ref(partyRef);
    _ref(requestRef);
    final session = await readSession();
    final identity = _identity(session);
    final result = await _call(
      'K261004001988',
      {
        'partyRef': partyRef,
        'requestRef': requestRef,
        if (seatChoice != null) 'seatChoice': seatChoice.toJson(),
      },
      session!,
      identity,
    );
    final quote = result['quote'];
    final status = result['status'];
    if (result['partyRef'] != partyRef ||
        quote is! Map ||
        quote['currency'] != 'CNY' ||
        ![
          'pending',
          'paying',
          'paid',
          'cancelled',
          'refunded',
        ].contains(status)) {
      _invalid();
    }
    final base = _money(quote['basePriceCents']);
    final surcharge = _money(quote['ageSurchargeCents']);
    final payable = _money(quote['payableCents']);
    if (base + surcharge != payable) _invalid();
    return TogetherBooking(
      ref: _ref(result['bookingRef']),
      partyRef: partyRef,
      status: status as String,
      basePriceMinor: base,
      ageSurchargeMinor: surcharge,
      payableMinor: payable,
    );
  }
}
