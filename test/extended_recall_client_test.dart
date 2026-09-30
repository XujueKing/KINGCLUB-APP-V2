import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/messaging/data/chat_outbox.dart';
import 'package:kingclub/src/features/messaging/data/direct_chat_controller.dart';
import 'package:kingclub/src/features/messaging/data/messaging_repository.dart';

class _Outbox implements ChatOutbox {
  @override
  Future<List<Map<String, dynamic>>> read() async => [];
  @override
  Future<void> put(Map<String, dynamic> message) async {}
  @override
  Future<void> remove(String id) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'quote is read-only and command carries exactly the confirmed server price',
    () async {
      final calls = <Map<String, dynamic>>[];
      final chat = DirectChatController(
        repository: MessagingRepository(
          account: 'me',
          call: (id, input) async {
            calls.add(input);
            if (input['quote'] == true) return {'cost': '7'};
            throw StateError('insufficient balance');
          },
        ),
        peer: 'friend',
        outbox: _Outbox(),
      );
      expect(await chat.quoteErase('message'), '7');
      expect(calls.single, {
        'peer': 'friend',
        'messageId': 'message',
        'mode': 'erase',
        'quote': true,
      });
      await expectLater(chat.erase('message', '7'), throwsStateError);
      expect(calls.last['expectedCost'], '7');
      expect(calls.last.containsKey('quote'), false);
      chat.dispose();
    },
  );
  test(
    'missing or malformed quote cannot become a zero-cost confirmation',
    () async {
      for (final cost in [null, 5, '-1', '5.0', '999999999999']) {
        final chat = DirectChatController(
          repository: MessagingRepository(
            account: 'me',
            call: (_, _) async => {'cost': cost},
          ),
          peer: 'friend',
          outbox: _Outbox(),
        );
        await expectLater(chat.quoteErase('message'), throwsStateError);
        chat.dispose();
      }
    },
  );
}
