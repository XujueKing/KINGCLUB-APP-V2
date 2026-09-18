# B 手机扫码测试包

## V1 实扫失败后的更新

首包用户反馈“无效”，真实链接证明旧印刷码使用 `tableld/shopld`。兼容修复及真实链接回归已完成，16 项测试、3 文件 analyze 通过。修复包 Gradle 108.8 秒，158.4 MB，SHA256 `CF5310B6177DA2AD97725F942D2E1181AB033C996ECEDF127741839891B16FE3`。已仅向 B 更新 commerce 包（install -r Success），启动 Status ok，前台 Activity 核对正确，保留应用数据。等待用户再次实扫；以下为首包历史记录。

用户授权仅 B 手机安装，并由用户实扫。B：PKL110，序列号 `TOHYQSINONBMJN6H`。A 不操作。

为与聊天开发并存，新增 Android `commerce` flavor，包名 `com.lingmei.kingclub.commerce`，桌面名称“KingClub 商务测试”。独立数据目录，不覆盖或清除 `com.lingmei.kingclub.v2preview`。首次使用需单独登录。

构建命令（commerce worktree）：

```powershell
$env:KINGCLUB_NOVORUDP_JNI_DIR=$null
D:\SDK\flutter\bin\flutter.bat build apk --profile --flavor commerce --target-platform android-arm64 --no-pub --dart-define=KINGCLUB_API_BASE_URL=https://test.wuyexin.cn/kingclub-v2 --dart-define=KINGCLUB_NOVORUDP_DEVICE_BINDING=false
```

该包用于扫码入口验证，未启用 NovoRUDP 本机绑定/中继，不作为聊天或去中心化网络验收包。测试 API 与已有预览环境一致，不含服务端密钥。桌台查询器尚未接通，识别 type=9 并跳转后预期显示“桌台点单服务尚未接通”；不能据此验收实际商品、支付或库存。

用户实扫步骤：登录 → 首页 SCAN QR（或扫一扫）→ 允许相机 → 扫现有桌卡 → 检查是否进入“桌台点单”页面 → 返回重扫。好友/群码保持独立分发；酒卡/券/门票尚未接通时显示明确提示。

安装完成：Gradle 177.5 秒，产物 `build/app/outputs/flutter-apk/app-commerce-profile.apk`（Flutter 报告 141.6 MB）。aapt 核对包名、标签及启动 Activity 正确；SHA256 `14AE7379826AE8423E98E8EED0D28AE63EA76A191C7866B7ACC6A3003406471D`。

仅向 B 执行 `adb -s TOHYQSINONBMJN6H install -r`，返回 Success。包更新时间为手机报告的 2026-09-18 09:51:14；`am start -W` 返回 Status ok，进程存在，topResumedActivity 为 commerce/MainActivity。未操作 A、未覆盖聊天预览版、未清数据。用户实扫与页面视觉验收待反馈；安装成功不等于扫码验收通过。
