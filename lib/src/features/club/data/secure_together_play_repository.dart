import '../../../core/networking/kingclub_secure_client.dart';
import '../../../core/session/secure_session_store.dart';
import '../../auth/domain/auth_repository.dart';
import '../../commerce/data/ordering_table_repository.dart';
import 'together_play.dart';

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
    implements TogetherPlayRepository, TogetherAdmissionRepository {
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
      startsAt: venue(start),
      endsAt: venue(end),
      hostName: r['publisherType'] == 'official' ? _text(r['storeName']) : '',
      merchantHost: r['publisherType'] == 'official',
      allowCoins: r['allowCoins'] == true,
      place: _text(r['place']),
      capacity: capacity,
      participants: const [],
      confirmedCount: confirmed,
      ticketNumber: bookingStatus == 'paid' && r['ticketNumber'] != null
          ? _ref(r['ticketNumber'])
          : null,
      assignedTable: bookingStatus == 'paid' && r['assignedTable'] != null
          ? _text(r['assignedTable'])
          : null,
      admissionUsed: bookingStatus == 'paid' && r['admissionUsed'] == true,
      feeMode: fee,
      priceMinor: _money(r['priceCents']),
      state: bookingStatus == 'paid'
          ? TogetherJoinState.joined
          : !end.isAfter(DateTime.now().toUtc())
          ? TogetherJoinState.closed
          : bookingStatus == 'pending'
          ? TogetherJoinState.pendingPayment
          : bookingStatus == 'cancelled' || bookingStatus == 'refunded'
          ? TogetherJoinState.cancelled
          : TogetherJoinState.available,
      description: _text(r['description']),
      rules: '',
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

  Future<TogetherBooking> payBooking(
    TogetherBooking booking, {
    required String method,
    required int coins,
    required String storeRef,
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

  /// Creates/retrieves an unpaid booking. Never interprets creation as admission.
  Future<TogetherBooking> prepareBooking(
    String partyRef, {
    required String requestRef,
  }) async {
    _ref(partyRef);
    _ref(requestRef);
    final session = await readSession();
    final identity = _identity(session);
    final result = await _call(
      'K261004001988',
      {'partyRef': partyRef, 'requestRef': requestRef},
      session!,
      identity,
    );
    final quote = result['quote'];
    final status = result['status'];
    if (result['partyRef'] != partyRef ||
        quote is! Map ||
        quote['currency'] != 'CNY' ||
        !['pending', 'paid', 'cancelled', 'refunded'].contains(status)) {
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
