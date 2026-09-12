import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/profile_settings/data/profile_avatar_store.dart';
import 'package:kingclub/src/features/profile_settings/presentation/personal_info_page.dart';

Widget _frame({
  VoidCallback? onBack,
  VoidCallback? onOpenPaymentSecurity,
  ProfileAvatarStore? avatarStore,
  Future<String?> Function()? pickAvatarImage,
  Future<String?> Function(String sourcePath)? adjustAvatarImage,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: const Size(393, 852), textScaler: textScaler),
      child: PersonalInfoPage(
        onBack: onBack,
        onOpenPaymentSecurity: onOpenPaymentSecurity,
        avatarStore: avatarStore,
        pickAvatarImage: pickAvatarImage,
        adjustAvatarImage: adjustAvatarImage,
      ),
    ),
  );
}

class _FakeAvatarStore implements ProfileAvatarStore {
  String? savedPath;

  @override
  Future<String?> load() async => savedPath;

  @override
  Future<String> persist(String sourcePath) async {
    savedPath = sourcePath;
    return sourcePath;
  }
}

void main() {
  const rows = [
    '会员称呼',
    '签名',
    '年龄/性别',
    '颜值',
    '能量值 | 等级',
    '灵根',
    '手机号码',
    '会员号',
    '修改支付密码',
  ];

  testWidgets('page reproduces the nine mini-program information rows', (
    tester,
  ) async {
    await tester.pumpWidget(_frame());

    expect(find.text('我的个人信息'), findsOneWidget);
    expect(find.byKey(const ValueKey('personal-info-avatar')), findsOneWidget);
    for (final row in rows) {
      expect(find.text(row), findsOneWidget);
    }
    expect(find.text('24岁/女'), findsOneWidget);
    expect(find.text('89分'), findsOneWidget);
    expect(find.text('200 | 1'), findsOneWidget);
    expect(find.text('木'), findsOneWidget);
    expect(find.text('186****3253'), findsOneWidget);
    expect(find.text('K45600000799'), findsOneWidget);
  });

  testWidgets('only editable rows expose visible arrows', (tester) async {
    await tester.pumpWidget(_frame());

    for (final id in const ['member-name', 'signature', 'payment-password']) {
      final arrow = tester.widget<SizedBox>(
        find.byKey(ValueKey('personal-info-arrow-$id')),
      );
      expect(arrow.child, isNotNull);
    }
    for (final id in const [
      'age-gender',
      'appearance',
      'energy-level',
      'spirit-root',
      'mobile',
      'member-id',
    ]) {
      final arrow = tester.widget<SizedBox>(
        find.byKey(ValueKey('personal-info-arrow-$id')),
      );
      expect(arrow.child, isNull);
    }
  });

  testWidgets('all values and arrow slots share the original trailing edge', (
    tester,
  ) async {
    await tester.pumpWidget(_frame());
    await tester.pumpAndSettle();

    final rightEdges = <double>[
      for (final value in const [
        '还未设置',
        '24岁/女',
        '89分',
        '200 | 1',
        '木',
        '186****3253',
        'K45600000799',
        '********',
      ])
        tester.getTopRight(find.text(value)).dx,
    ];
    expect(
      rightEdges.reduce((a, b) => a > b ? a : b) -
          rightEdges.reduce((a, b) => a < b ? a : b),
      lessThan(.5),
    );
  });

  testWidgets('avatar can be selected adjusted and saved locally', (
    tester,
  ) async {
    final store = _FakeAvatarStore();
    var pickerCalls = 0;
    var adjustmentInput = '';
    await tester.pumpWidget(
      _frame(
        avatarStore: store,
        pickAvatarImage: () async {
          pickerCalls += 1;
          return 'picked-avatar.jpg';
        },
        adjustAvatarImage: (sourcePath) async {
          adjustmentInput = sourcePath;
          return 'cropped-avatar.png';
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('personal-info-avatar-action')));
    await tester.pumpAndSettle();

    expect(pickerCalls, 1);
    expect(adjustmentInput, 'picked-avatar.jpg');
    expect(store.savedPath, 'cropped-avatar.png');
    expect(find.text('头像已更新'), findsOneWidget);
  });

  testWidgets('member name and signature can be edited locally', (
    tester,
  ) async {
    await tester.pumpWidget(_frame());

    await tester.tap(find.byKey(const ValueKey('personal-info-member-name')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('personal-info-input-会员称呼')),
      '小琪',
    );
    await tester.tap(find.byKey(const ValueKey('personal-info-confirm-会员称呼')));
    await tester.pumpAndSettle();
    expect(find.text('小琪'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('personal-info-signature')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('personal-info-input-签名')),
      '今晚见',
    );
    await tester.tap(find.byKey(const ValueKey('personal-info-confirm-签名')));
    await tester.pumpAndSettle();
    expect(find.text('今晚见'), findsOneWidget);
  });

  testWidgets('payment password and back use fixed callbacks', (tester) async {
    var paymentOpened = 0;
    var backed = 0;
    await tester.pumpWidget(
      _frame(
        onOpenPaymentSecurity: () => paymentOpened++,
        onBack: () => backed++,
      ),
    );

    final payment = find.byKey(
      const ValueKey('personal-info-payment-password'),
    );
    await tester.ensureVisible(payment);
    await tester.tap(payment);
    expect(paymentOpened, 1);

    await tester.tap(find.byKey(const ValueKey('personal-info-back')));
    expect(backed, 1);
  });

  testWidgets('200 percent text stays scrollable without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(_frame(textScaler: const TextScaler.linear(2)));
    await tester.pumpAndSettle();

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
