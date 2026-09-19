# 商业页面错误显示英文的根配置修复

用户反馈菜单和设置显示英文。实际读取 B 手机系统语言为 zh-CN；MaterialApp.router 未声明 supportedLocales/localizationsDelegates，框架仅默认支持 en_US，新商业页面读取 Localizations.localeOf 后错误选中英文。不是用户切换了语言，也不应逐页硬编码中文掩盖根因。

新增 king_localizations.dart，统一声明简中 zh-Hans-CN、英文 en、繁中 zh-Hant-TW、泰语 th，以及 Flutter SDK 的 Material/Cupertino/Widgets 本地化委托。简中排列第一作为不支持语言时的回退，支持的系统语言正常匹配。pubspec 将既有传递依赖 flutter_localizations 声明为直接 SDK 依赖，没有升级第三方包。

根 MaterialApp.router 接入配置，日期选择器和按钮语言随之正确加载。尚未新增用户手动切换语言设置，不声称所有历史硬编码页面已完成四语言翻译。

5 个语言匹配/系统控件测试加 11 个桌台页面测试共 16 项通过，3 个文件静态检查通过。测试覆盖中文系统不再落入英文、繁中、泰文、英文、其他语言回退中文；仅商业独立 worktree 改动，聊天主工作目录未修改。

commerce/profile arm64 构建通过，APK SHA256 9E67AD870F13A115FB0E0A5F89754C5398BBEDD6686E3E91C80A4DB18E9651E1。已在授权 B 手机 install -r 成功并启动，未清数据。用户实际页面语言待复查。
