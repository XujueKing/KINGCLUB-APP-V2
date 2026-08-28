# 扫码识别与安全分流页验收

- [x] overlay 入口、来源恢复、非法引用和会话守卫明确
- [x] rationale、权限、相机、解析、拒绝、错误和导航状态明确
- [x] 三类 allowlist、动态 URL 拒绝和目标页二次读取明确
- [x] SingleFlight、生命周期、迟到响应和补光灯规则明确
- [x] payload、图像、日志、缓存和可访问性边界明确
- [x] 用户于 2026-08-25 批准 Safe Scanner Wireframe v1 与消费者 allowlist

## UI Mock 验收

- [x] SCAN-M01～M16 均有可执行 Fake 状态或自动化用例
- [x] 三类 allowlist 均只发出一次类型化意图
- [x] 重复识别、解析中关闭和迟到结果均不产生第二次导航
- [x] 进后台暂停扫描并关闭补光灯，回前台才恢复
- [x] 360～430dp、200% 文字和减少动画可达且无溢出
- [x] Android 设备已捕获用途说明、Fake 取景、拦截和允许意图四个关键步骤
- [x] 未声明真实相机权限，未调用相机、SDK、超级接口或外部 URL

2026-08-28 页面标记 `UI Mock Implemented`；真实权限和扫码能力仍受项目级 `UI Flow Approved` 门禁阻断。
