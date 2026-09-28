# B 手机扫码测试包

## 首屏密度与透明覆盖层修正

用户反馈字号仍太大、首屏瓶数不对、购物车不透明。已按页面宽度设定目录文字比例，不再受系统 1.35 大字号放大；根据实际列表可视高度计算商品行高。底部购物车从 bottomNavigationBar 改为 Stack 覆盖层，alpha 0.6 → 0.9 → 1 黑色渐变，商品可在后方显示。六种尺寸/字号场景验证第四瓶跨越购物车顶边且渐变上端不是全不透明；15 项相关测试及 2 文件 analyze 通过。

Gradle 417.4 秒，158.4 MB；SHA256 `D8B9EB6AEE4DDE1AF570AA06E88332B96BF1FDA9BDB8E80C809A8F11ED76A295`。B commerce 包 install -r Success，启动 Status ok，前台 Activity 确认。真实手机视觉待用户复扫；生产目标及支付进度见 PRODUCTION_GOAL.md。

## 自适应样式更新

按用户要求去掉预览横幅并对照旧设计调整桌号、分类、商品比例与底部购物栏。320/393/430 宽及 1.35 倍字号覆盖；17 项布局/交互测试通过，3 文件 analyze 通过。真实商品与下单仍未接入，移除横幅不是接通业务的声明。

Gradle 174.7 秒，158.4 MB，SHA256 `FD772601FB97630D4DDAB6220562843F2329FD1FE346793F24302FD056451EC4`。仅 B commerce 包 install -r Success，启动 Status ok，前台 Activity 已确认；保留数据。待用户再扫 V1 做实机视觉验收，未宣称 1:1 验收完成。

## 接回点单页面的更新

用户已确认上一包能扫码路由。本节点仅 commerce flavor 开启标注清楚的点单 UI 预览：携带桌名 V1、原有分类和商品、初始空购物袋，结算不进入订单。19 项相关测试及 4 文件 analyze 通过。

Gradle 133.4 秒，158.4 MB；SHA256 `BDFA90831371B4294541E1AA52182D0A357AE35CA11FDC5EFDD29136A4AAFCA5`。仅 B commerce 包 `install -r` Success，启动 Status ok、前台 Activity 正确，保留数据。等待用户复扫检查 V1、列表滚动、加减商品及金额；没有宣称真实门店解析、库存或支付接通。该预览更新取代此前扫码只能停在服务未接通提示的 commerce 行为。

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
