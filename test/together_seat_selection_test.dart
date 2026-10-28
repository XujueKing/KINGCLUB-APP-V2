import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/club/data/together_play.dart';
import 'package:kingclub/src/features/club/presentation/together_play_page.dart';
import 'package:kingclub/src/features/club/presentation/together_seat_cards.dart';
import 'package:kingclub/src/features/club/presentation/together_seat_picker.dart';

import 'together_play_test.dart' show fixture;

void main() {
  testWidgets(
    'store-branded cards show the real store identity and separate small heading',
    (tester) async {
      final party = fixture(
        merchantHost: false,
        cardPublisher: 'store',
        cardKicker: '本周五 (10月30日)',
        cardStoreName: 'KING CLUB',
        cardStoreSubtitle: '天元区湖南工大店',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TogetherAvailableRow(
                party: party,
                onTap: () {},
                showAction: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TogetherStoreLogo), findsOneWidget);
      expect(find.text('KING CLUB'), findsOneWidget);
      expect(find.text('天元区湖南工大店'), findsOneWidget);
      expect(party.storeName, '样例门店');
      expect(find.text('样例发起人'), findsNothing);
      expect(find.text('本周五 (10月30日)'), findsOneWidget);
      expect(find.text(party.feeLabel), findsNothing);
      final kicker = find.byKey(ValueKey('together-kicker-${party.ref}'));
      final headline = find.byKey(
        ValueKey('together-editorial-title-${party.ref}'),
      );
      final subtitle = find.byKey(
        ValueKey('together-editorial-subtitle-${party.ref}'),
      );
      expect(
        tester.widget<Text>(kicker).style!.fontSize,
        tester.widget<Text>(subtitle).style!.fontSize,
      );
      expect(tester.widget<Text>(kicker).style!.fontWeight, FontWeight.w700);
      expect(
        tester.getTopLeft(headline).dy - tester.getBottomLeft(kicker).dy,
        8,
      );
      expect(
        tester.getTopLeft(subtitle).dy - tester.getBottomLeft(headline).dy,
        8,
      );
      expect(
        party
            .withAdmission(
              number: 'ticket',
              code: 'code',
              expiresAt: DateTime(2030),
            )
            .cardPublisher,
        'store',
      );
    },
  );
  testWidgets(
    'publisher changes to a tight 5 by 2 avatar grid at ten, not eleven',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(402, 874));
      for (final count in [9, 10, 11]) {
        final party = fixture(capacity: 12, count: count);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: TogetherAvailableRow(
                  party: party,
                  onTap: () {},
                  showAction: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(TogetherAttendeeGrid),
          count >= 10 ? findsOneWidget : findsNothing,
        );
        if (count >= 10) {
          final avatars = find.descendant(
            of: find.byType(TogetherAttendeeGrid),
            matching: find.byType(TogetherMemberAvatar),
          );
          expect(avatars, findsNWidgets(10));
          expect(
            tester.getTopLeft(avatars.at(0)).dy,
            tester.getTopLeft(avatars.at(4)).dy,
          );
          expect(
            tester.getTopLeft(avatars.at(5)).dy -
                tester.getTopLeft(avatars.at(0)).dy,
            32,
          );
        }
        expect(tester.takeException(), isNull);
      }
      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets(
    'self selection respects gender, occupied and payment-reserved seats',
    (tester) async {
      final picked = <TogetherSeatChoice>[];
      final party = TogetherParty(
        ref: 'p',
        theme: '主题派对',
        cityCode: '430200',
        cityName: '株洲市',
        storeRef: 's',
        storeName: '门店',
        startsAt: DateTime(2030),
        endsAt: DateTime(2030, 1, 2),
        hostName: '发起人',
        merchantHost: true,
        place: '店内',
        capacity: 6,
        participants: const [],
        feeMode: TogetherFeeMode.aa,
        priceMinor: 100,
        state: TogetherJoinState.available,
        description: '',
        rules: '',
        myGender: TogetherGender.male,
        tables: const [
          TogetherActivityTable(
            ref: '888',
            name: '888卡座',
            capacity: 6,
            maleSeats: 3,
            femaleSeats: 3,
            reservedSeats: [1],
            participants: [
              TogetherParticipant(
                name: '已报名',
                gender: TogetherGender.male,
                seatIndex: 0,
                tableRef: '888',
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TogetherSeatCards(party: party, onSelect: picked.add),
          ),
        ),
      );
      final avatars = find.byType(TogetherMemberAvatar);
      expect(avatars, findsNWidgets(6));
      for (final i in [0, 1, 3, 4, 5]) {
        await tester.tap(avatars.at(i));
      }
      expect(picked, isEmpty);
      await tester.tap(avatars.at(2));
      expect(picked.single.toJson(), {
        'mode': 'selected',
        'tableRef': '888',
        'seatIndex': 2,
      });
      expect(
        tester.getTopLeft(avatars.at(3)).dy,
        greaterThan(tester.getTopLeft(avatars.at(0)).dy),
      );

      TogetherSeatChoice? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showTogetherSeatPicker(context, party);
                },
                child: const Text('报名'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('报名'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('自己选座'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      await tester.tap(find.byType(TogetherMemberAvatar).at(2));
      await tester.pump();
      await tester.tap(find.text('确认选座，继续报名'));
      await tester.pumpAndSettle();
      expect(result?.toJson(), {
        'mode': 'selected',
        'tableRef': '888',
        'seatIndex': 2,
      });
    },
  );
}
