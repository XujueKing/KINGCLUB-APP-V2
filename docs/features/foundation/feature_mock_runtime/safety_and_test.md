# Mock Runtime 数据安全、测试与退出策略

## 数据安全

- Fixture 使用明显虚构的姓名、头像、手机号占位、订单号和聊天内容；禁止导入生产导出、通讯录或真实截图元数据。
- Token、验证码、支付凭据和身份证字段只允许使用不可误认的占位值，且不得写入日志。
- 场景报告只包含 scenario/version/seed/checkpoint/稳定错误分类，不包含页面 DTO 全文。

## 防止真实接入

- Mock 构建的网络端口默认 deny-all；任何未预期 socket/HTTP 尝试令自动化测试失败。
- 生产域名、生产证书、支付/推送正式配置和真实 SDK 初始化不进入 UI Mock 提交。
- CI 分别扫描依赖图、配置和运行时出站请求，证明业务页面只绑定 Fake。

## 自动化与验收

- Manifest schema、稳定 seed、重置、虚拟时钟和 generation 丢弃做单元测试。
- 48 页状态使用 Widget/golden 测试；J01～J07 使用集成测试。
- Android/iOS 手机尺寸、字体缩放、减少动态效果、前后台和系统返回纳入 UI 验收。
- 演示失败必须可通过 scenarioId、version、seed 和 checkpoint 重现。

## 退出与回滚

- 真实接入阶段保留全部 Fake，用相同契约跑回归；不删除 Mock Runtime。
- 真实 adapter 出现问题可在非生产验收环境切回 Fake，但生产不得远程切换到伪业务结果。
- 契约变化先更新文档、fixture schema 和 Fake，再更新真实 adapter。
