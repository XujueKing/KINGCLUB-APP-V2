import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/profile_settings/presentation/edit_profile_page.dart';

void main() {
  Widget subject({
    ValueChanged<EditableProfileResult>? onSaved,
    VoidCallback? onBack,
    VoidCallback? onSessionResetRequested,
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    return MaterialApp(
      theme: ThemeData.dark(useMaterial3: true),
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(393, 852),
          textScaler: textScaler,
        ),
        child: EditProfilePage(
          nickname: '杨嘉琪',
          signature: '',
          onSaved: onSaved,
          onBack: onBack,
          onSessionResetRequested: onSessionResetRequested,
        ),
      ),
    );
  }

  Future<void> editNickname(WidgetTester tester, String value) async {
    await tester.tap(find.byKey(const ValueKey('edit-profile-nickname')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('edit-profile-input-nickname')),
      value,
    );
    await tester.tap(find.text('确认修改'));
    await tester.pumpAndSettle();
  }

  Future<void> chooseScenario(
    WidgetTester tester,
    EditProfileMockSaveOutcome outcome,
  ) async {
    await tester.longPress(find.byKey(const ValueKey('edit-profile-title')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(ValueKey('edit-profile-scenario-${outcome.name}')),
    );
    await tester.pumpAndSettle();
  }

  Future<Finder> tapSave(WidgetTester tester) async {
    final save = find.byKey(const ValueKey('edit-profile-save'));
    await tester.scrollUntilVisible(
      save,
      360,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(save);
    return save;
  }

  testWidgets('保存成功只返回 Fake 昵称和签名', (tester) async {
    EditableProfileResult? result;
    await tester.pumpWidget(subject(onSaved: (value) => result = value));

    await editNickname(tester, '杨嘉琪 King');
    await tapSave(tester);
    await tester.pump();

    expect(find.byKey(const ValueKey('edit-profile-saving')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 450));
    expect(result?.nickname, '杨嘉琪 King');
    expect(result?.signature, '');
  });

  testWidgets('昵称校验错误不会清空当前输入', (tester) async {
    await tester.pumpWidget(subject());
    await tester.tap(find.byKey(const ValueKey('edit-profile-nickname')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('edit-profile-input-nickname')),
      '杨',
    );
    await tester.tap(find.text('确认修改'));
    await tester.pump();

    expect(find.text('昵称需要 2～16 个字符'), findsOneWidget);
    expect(find.text('杨'), findsOneWidget);
  });

  testWidgets('有修改时返回先确认且继续编辑不丢草稿', (tester) async {
    var backed = false;
    await tester.pumpWidget(subject(onBack: () => backed = true));
    await editNickname(tester, '草稿昵称');

    await tester.tap(find.byKey(const ValueKey('legacy-back')));
    await tester.pumpAndSettle();
    expect(find.text('放弃修改？'), findsOneWidget);
    await tester.tap(find.text('继续编辑'));
    await tester.pumpAndSettle();
    expect(find.text('草稿昵称'), findsOneWidget);
    expect(backed, isFalse);

    await tester.tap(find.byKey(const ValueKey('legacy-back')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('放弃'));
    await tester.pumpAndSettle();
    expect(backed, isTrue);
  });

  testWidgets('版本冲突不静默覆盖且可重新加载', (tester) async {
    await tester.pumpWidget(subject());
    await editNickname(tester, '待合并草稿');
    await chooseScenario(tester, EditProfileMockSaveOutcome.versionConflict);

    await tapSave(tester);
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('edit-profile-version-conflict')),
      findsOneWidget,
    );
    expect(find.text('待合并草稿'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('edit-profile-conflict-reload')),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('edit-profile-status-banner')),
      -360,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('杨嘉琪'), findsOneWidget);
    expect(find.textContaining('已重新加载'), findsOneWidget);
  });

  testWidgets('结果未知不重复写入且查询后收敛', (tester) async {
    var savedCount = 0;
    await tester.pumpWidget(subject(onSaved: (_) => savedCount += 1));
    await chooseScenario(tester, EditProfileMockSaveOutcome.resultUnknown);

    final save = await tapSave(tester);
    await tester.tap(save, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('edit-profile-result-unknown')),
      findsOneWidget,
    );
    expect(savedCount, 0);

    await tester.tap(find.byKey(const ValueKey('edit-profile-query-latest')));
    await tester.pumpAndSettle();
    expect(savedCount, 1);
  });

  testWidgets('头像失败仅显示稳定提示且不读取相册', (tester) async {
    await tester.pumpWidget(subject());
    await tester.tap(find.byKey(const ValueKey('edit-profile-empty-avatar')));
    await tester.pumpAndSettle();
    expect(find.textContaining('不会读取真实相册'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('edit-profile-avatar-upload-failed')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('仅头像受影响'), findsOneWidget);
    expect(find.text('杨嘉琪'), findsOneWidget);
  });

  testWidgets('会话失效清理草稿并请求全局重置', (tester) async {
    var reset = false;
    await tester.pumpWidget(
      subject(onSessionResetRequested: () => reset = true),
    );
    await chooseScenario(tester, EditProfileMockSaveOutcome.sessionInvalid);

    await tapSave(tester);
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('edit-profile-session-invalid')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('edit-profile-session-confirm')),
    );
    await tester.pumpAndSettle();
    expect(reset, isTrue);
  });

  testWidgets('200% 字体下列表可滚动且无溢出', (tester) async {
    await tester.pumpWidget(subject(textScaler: const TextScaler.linear(2)));
    await tester.pumpAndSettle();

    expect(find.text('我的个人信息'), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
