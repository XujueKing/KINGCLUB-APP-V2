# 新机器工具链与审计整改

## 范围

用户根据 2026-09-29 功能审计同意按建议推进，随后明确只使用 main。
不扩大为生产部署、数据库迁移、真实付款或测试手机操作授权。

## 工具链

- 保持 ADR-0001：Flutter 3.47.1 / Dart 3.13.1。
- 官方 Flutter 标签对应提交 `6655482ec06e547f90abf8ae7590466f4415978d`。
- 本机独立安装于 `D:/WEB3_AI/tools/flutter-3.47.1`，不覆盖旧 SDK、不改全局 PATH。
- Windows 使用 `scripts/flutter.ps1`；默认从仓库同级 `tools/flutter-3.47.1` 读取，也可设置 `KINGCLUB_FLUTTER_ROOT`。脚本检查版本和提交，错配即停止。
- 安装来源：[官方 SDK 归档与安装说明](https://docs.flutter.dev/install/archive)。归档索引本次返回 404，改从官方 Git 仓库精确标签克隆并由 Flutter 工具获取引擎/Dart。

```powershell
./scripts/flutter.ps1 --version
./scripts/flutter.ps1 pub get --enforce-lockfile
./scripts/flutter.ps1 analyze --no-pub
./scripts/flutter.ps1 test --no-pub test/live_order_payment_page_test.dart
```

## 安全整改验收契约

1. 真实模式不得打开没有真实服务的 PIN 修改、永久注销、演示订单/支付/资产流水、AA/VIP 和入场凭证。保留导航目的与明确“暂未开放”状态，不把未开放显示成无订单或无资产；不删除 Mock 测试流程。
2. 真实扫码订单恢复必须保留已付款凭据；仅当持久化商品范围与当前购物车一致时通知购物车扣减，且每次页面生命周期最多一次。
3. 恢复其他商品范围的待付款订单时仅查询，不发起新付款，不展示当前购物车作为旧订单明细，不清除当前购物车。
4. 不支持的平台或后付费模式必须在创建支付订单前明确阻断。此为能力边界提示，不代表 iOS 微信支付或后付费已实现。
5. 不修改真实登录/注册 UI，不新接尚未确认的接口，不把替身测试当作真实付款验收。

## 后续边界

真实订单列表/资产流水接口、后付费完整链、iOS 支付桥、推送事件标识重构及全模块联调仍需后续节点。NovoRUDP 外部源码固定版本与 NDK、Android 构建链不因 Dart 可运行而自动完成。

## 工具链节点验证

- `scripts/flutter.ps1 --version`：通过，版本/提交与上述固定基线一致。
- `flutter pub get --enforce-lockfile`：通过，未修改 `pubspec.lock`。
- 既有 `live_order_payment_page_test.dart`：3 项通过，仅客户端替身测试。
- 全量 `flutter analyze --no-pub`：无 error/warning，但有 9 个既存 info（测试中 if 缺少花括号），命令退出 1，不能记为全量门禁通过。本节点不顺带改聊天测试。
- Android/iOS 打包与真机、后端依赖和线上服务未在本节点验证。
