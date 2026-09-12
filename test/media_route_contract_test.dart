import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'app routes and media cannot bypass native transitions or disk cache',
    () {
      final forbidden = RegExp(
        r'Image\.network|NetworkImage\(|SvgPicture\.network|VideoPlayerController\.network|CustomTransitionPage|PageRouteBuilder|CupertinoPageRoute',
      );
      final offenders = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (f) =>
                f.path.endsWith('.dart') &&
                forbidden.hasMatch(f.readAsStringSync()),
          )
          .map((f) => f.path)
          .toList();
      expect(
        offenders,
        isEmpty,
        reason: 'Use Material pages and account-scoped disk media cache',
      );
    },
  );
}
