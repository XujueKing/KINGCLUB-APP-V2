# Store tables 点击无响应修复

B 手机日志定位到 Navigator.of 的空值异常，调用点为 SettingsRoute.build 的入口回调。typed route 的 buildPage 提前构建 child，传入的路由层 context 不在页面 Navigator 下；此前组件测试直接挂载列表页，未覆盖从真实设置路由点击的路径。

SettingsRoute 加 Builder，商业入口改用页面内部 pageContext 推入列表，语言上下文也取该层。其余原有 GoRouter 返回/账号安全回调保留。未修改服务器、门店权限或数据。

新增 store_tables_navigation_test.dart，通过 GoRouter/pageBuilder 构建真实 SettingsRoute，实际点击 Store tables 并返回；安全存储注入空会话，测试不登录或请求服务器。开启管理编译开关后测试通过，改动静态检查通过。后续组件测试不能代替路由点击验收。

修复后 commerce/profile arm64 APK 已重新构建（Gradle 成功，原插件 KGP 兼容性警告仍存在），在 B/PKL110 使用 install -r 成功覆盖并启动，未清登录数据。等待用户点击验收；未代用户修改营业配置。
