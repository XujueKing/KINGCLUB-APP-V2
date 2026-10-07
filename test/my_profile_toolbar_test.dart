import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/profile_settings/presentation/my_profile_page.dart';

void main() {
  testWidgets('merchant defaults visible and arrows reveal hidden shortcuts', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final calls = <Map<String, dynamic>>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MyProfilePage(
            partnerCall: (p) async {
              calls.add(p);
              if (p['action'] == 'merchant')
                return {
                  'store': {
                    'name': 'Test store',
                    'address': 'Address',
                    'currency': 'CNY',
                  },
                };
              return {
                'stores': [
                  {'ref': 'test-store', 'name': 'Test store'},
                ],
              };
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final partner = find.byKey(const ValueKey('my-profile-partner'));
    final merchant = find.byKey(const ValueKey('my-profile-merchant'));
    await tester.ensureVisible(partner);
    expect(
      tester.getRect(merchant).left,
      greaterThan(tester.getRect(partner).left),
    );
    expect(tester.getRect(merchant).width, tester.getRect(partner).width);
    final services = find.byKey(const ValueKey('my-profile-services'));
    final viewport = tester.getRect(
      find
          .ancestor(of: services, matching: find.byType(SingleChildScrollView))
          .first,
    );
    expect(
      tester.getRect(merchant).right,
      lessThanOrEqualTo(viewport.right + .1),
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('my-profile-bump'))).right,
      lessThanOrEqualTo(viewport.left + .1),
    );
    expect(
      find.byKey(const ValueKey('my-profile-services-earlier')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('my-profile-services-later')),
      findsNothing,
    );
    await tester.drag(services, const Offset(200, 0));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('my-profile-services-earlier')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('my-profile-services-later')),
      findsOneWidget,
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('my-profile-bump'))).left,
      closeTo(viewport.left, .1),
    );
    await tester.tap(find.byKey(const ValueKey('my-profile-services-later')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('my-profile-services-earlier')),
      findsOneWidget,
    );
    await tester.tap(merchant);
    await tester.pumpAndSettle();
    expect(calls.last, {'action': 'merchant', 'storeRef': 'test-store'});
    expect(find.text('Test store'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets('non merchant account has no merchant entry', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MyProfilePage(partnerCall: (_) async => {'stores': []}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('my-profile-merchant')), findsNothing);
    expect(
      find.byKey(const ValueKey('my-profile-services-earlier')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('my-profile-services-later')),
      findsNothing,
    );
    tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!
        .jumpTo(500);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('my-profile-selected-tab-arrow-动态')),
      findsOneWidget,
    );
  });

  testWidgets('orders has one service entry and no toolbar duplicate', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: MyProfilePage(onOpenOrders: () => opened++)),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('my-profile-orders-shortcut')),
      findsNothing,
    );
    await tester.ensureVisible(find.text('我的订单'));
    await tester.tap(find.text('我的订单'));
    expect(opened, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('我的主页左上工具栏保持旧版图标与点击区比例', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var qrOpened = false;
    var settingsOpened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(393, 852)),
          child: Scaffold(
            body: MyProfilePage(
              onOpenPersonalQr: () => qrOpened = true,
              onOpenSettings: () => settingsOpened = true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final qrTap = tester.getRect(find.byKey(const ValueKey('my-profile-qr')));
    final settingsTap = tester.getRect(
      find.byKey(const ValueKey('my-profile-settings')),
    );
    final qrImage = tester.getRect(
      find.byKey(const ValueKey('my-profile-qr-image')),
    );
    final settingsImage = tester.getRect(
      find.byKey(const ValueKey('my-profile-settings-image')),
    );
    final toolbar = tester.getRect(
      find.byKey(const ValueKey('my-profile-top-tools')),
    );

    const scale = 393 / 750;
    expect(qrImage.width, closeTo(40 * scale, .01));
    expect(qrImage.height, closeTo(40 * scale, .01));
    expect(settingsImage.width, closeTo(40 * scale, .01));
    expect(settingsImage.height, closeTo(40 * scale, .01));
    expect(qrTap.width / qrImage.width, closeTo(2, .01));
    expect(settingsTap.width / settingsImage.width, closeTo(2, .01));
    expect(qrImage.center.dx, lessThan(60));
    expect(settingsImage.center.dx, greaterThan(330));
    final exp = tester.getRect(find.byKey(const ValueKey('my-profile-exp')));
    expect(exp.left, greaterThanOrEqualTo(qrTap.right));
    expect(exp.right, lessThan(settingsTap.left));
    expect(toolbar.right, lessThanOrEqualTo(settingsTap.left));

    await tester.tap(find.byKey(const ValueKey('my-profile-qr')));
    await tester.tap(find.byKey(const ValueKey('my-profile-settings')));
    expect(qrOpened, isTrue);
    expect(settingsOpened, isTrue);
  });
}
