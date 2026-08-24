# 应用启动与环境评审记录

## 2026-08-24 正式评审

### 已确认决策

1. 使用唯一 `BootstrapHost` 先渲染本地首帧，再装配正式 App Root，禁止白屏和第二套 Router/ProviderScope。
2. P0～P4 只处理本地关键能力；K103/K104、深链恢复和最终认证路由由 `/auth/bootstrap` 在首帧后完成。
3. `dev/staging/prod` 构建、应用标识、网络地址、安全存储和数据容器隔离，运行时不可切换环境。
4. 本地会话只输出 `absent/present/corruptCleared/unavailable` 候选，不向 bootstrap 暴露凭据或授予认证状态。
5. 进程级 SingleFlight、generation 和迟到结果丢弃规则适用于冷启动、重试和生命周期变化。
6. 完整诊断及第三方 SDK 失败可降级；配置和安全存储等关键安全依赖失败关闭。
7. `deviceInstanceId` 为当前安装和环境内稳定的安全随机值，不由硬件标识、手机号或账号派生，也不进入日志。

### 结论

用户于 2026-08-24 明确确认按上述方案继续。目标、边界、状态、配置 schema、异常恢复、隐私、安全、灰度、回滚和测试矩阵完整，本模块更新为 `Approved for Development`。

正式 applicationId/bundleId、生产域名、签名、CI 和双端真机数据属于发布/实现门禁，不改变本次文档批准；这些输入确认前不得产出生产包。
