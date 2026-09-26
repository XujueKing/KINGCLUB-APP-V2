# 资料媒体路由的权限版本

点击资料媒体到新路由实际构建之间可能发生权限刷新。此前 ProfileMediaPage 只订阅后续 visibility 通知，若通知先于 initState，会遗漏失效并可能读取已有缓存。

在点击时捕获 visibility 版本并传入路由，媒体页初始化核对版本，后续继续保持原有失效监听。撤权后的旧路由不因稍后的重新授权恢复，需从重新加载后的资料页重新点击。该改动不删除聊天附件，不改变关注关系或服务端权限。

验证覆盖：权限在页面创建前失效、页面已打开后失效，以及再次改变版本不恢复旧页面。组件验证使用非空测试 API 配置，避免因未配置 API 而产生假阳性。实机待合并安装验证，不将组件验证当作设备缓存撤权通过。

已运行 `flutter test --dart-define=KINGCLUB_API_BASE_URL=https://example.invalid test/profile_media_permission_test.dart test/public_member_page_test.dart`，8 项全部通过（新增两项没有跳过）；三个改动 Dart 文件定向 analyze 无问题。未修改服务端或安装到 A/B。
