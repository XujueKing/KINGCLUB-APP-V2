import 'package:flutter_test/flutter_test.dart';
import 'package:kingclub/src/features/contacts/presentation/user_profile_page.dart';
import 'package:kingclub/src/navigation/app_router.dart';

void main() {
  test('social friendship pages expose stable typed locations', () {
    expect(const AddFriendRoute().location, '/social/add');
    expect(const FriendRequestsRoute().location, '/social/requests');
    expect(
      const UserProfileRoute(
        UserProfileRouteArgs(
          'contact-alice',
          relationship: UserProfileRelationship.stranger,
        ),
      ).location,
      '/social/profile',
    );
    expect(
      const SendFriendRequestRoute(
        SendFriendRequestRouteArgs('contact-alice', '艾琳'),
      ).location,
      '/social/request/send',
    );
    expect(
      const FriendRemarkRoute(
        FriendRemarkRouteArgs('contact-alice', '艾琳', '周末见'),
      ).location,
      '/social/friend/remark',
    );
    expect(
      const RelationshipPermissionsRoute(
        RelationshipPermissionsRouteArgs('contact-alice', '艾琳'),
      ).location,
      '/social/friend/permissions',
    );
    expect(const BlacklistRoute().location, '/social/blacklist');
  });
}
