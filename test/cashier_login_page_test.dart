import 'package:flutter/material.dart';
import 'package:kingclub/src/core/session/secure_session_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/scanner/data/cashier_login_repository.dart';
import 'package:kingclub/src/features/scanner/presentation/cashier_login_page.dart';

class _Repository implements CashierLoginRepository {
  final List<String> calls = [];
  bool unknown = false;
  String status = 'pending';
  DateTime expires = DateTime.now().add(const Duration(minutes: 5));
  List<CashierLoginStore> stores = [
    const CashierLoginStore(ref: 'store', name: '湖南工大店'),
  ];
  @override
  Future<CashierLoginChallenge> inspect(String id) async {
    calls.add('inspect');
    return CashierLoginChallenge(
      status: status,
      deviceLabel: '前台收银机',
      expiresAt: expires,
      stores: stores,
    );
  }

  @override
  Future<String> approve(String id, String store) async {
    calls.add('approve:$store');
    status = 'approved';
    if (unknown) throw Exception('response lost');
    return status;
  }

  @override
  Future<String> reject(String id) async {
    calls.add('reject');
    return 'rejected';
  }
}

void main() {
  Future<void> open(WidgetTester tester, _Repository repo) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CashierLoginPage(challengeId: 'a' * 64, repository: repo),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('session change disables approval', (tester) async {
    final repo = _Repository();
    await open(tester, repo);
    SecureSessionStore.changes.add(null);
    await tester.pumpAndSettle();
    expect(find.text('确认登录'), findsNothing);
    expect(find.text('登录状态已变化，请返回重新扫码'), findsOneWidget);
    expect(repo.calls, ['inspect']);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'scan inspects only; explicit confirmation approves selected store',
    (tester) async {
      final repo = _Repository();
      await open(tester, repo);
      expect(repo.calls, ['inspect']);
      expect(find.text('前台收银机'), findsOneWidget);
      await tester.tap(find.text('确认登录'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['inspect', 'approve:store']);
      expect(find.text('收银台登录已确认'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('multiple stores require selection and cancel never approves', (
    tester,
  ) async {
    final repo = _Repository()
      ..stores.add(const CashierLoginStore(ref: 'second', name: '第二门店'));
    await open(tester, repo);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('cashier-login-approve')),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('第二门店'));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('cashier-login-approve')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.text('取消登录'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['inspect', 'reject']);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'lost approval response queries same request without another approval',
    (tester) async {
      final repo = _Repository()..unknown = true;
      await open(tester, repo);
      await tester.tap(find.text('确认登录'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('cashier-login-approve')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('查询操作结果'));
      await tester.pumpAndSettle();
      expect(repo.calls, ['inspect', 'approve:store', 'inspect']);
      expect(find.text('收银台登录已确认'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('expired challenge offers no approval', (tester) async {
    final repo = _Repository()
      ..expires = DateTime.now().subtract(const Duration(seconds: 1));
    await open(tester, repo);
    expect(find.text('确认登录'), findsNothing);
    expect(repo.calls, ['inspect']);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
