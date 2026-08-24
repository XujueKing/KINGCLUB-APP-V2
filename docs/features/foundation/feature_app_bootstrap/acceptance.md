# 应用启动与环境验收

## 文档准入

- [x] dev/staging/prod 不可变配置、字段和失败关闭规则明确
- [x] BootstrapHost、P0～P6 顺序、首帧边界及关键/非关键任务明确
- [x] bootstrap 与 navigation、session、networking、observability 的责任边界明确
- [x] 重入、generation、生命周期和迟到结果处理明确
- [x] 配置、SecureStore、依赖装配与非关键 SDK 失败矩阵明确
- [x] 单元、Widget、集成和双端真机测试场景可执行
- [x] 日志、隐私、灰度和回滚要求明确
- [x] 用户于 2026-08-24 批准本模块，状态更新为 `Approved for Development`

## 实现验收

- [ ] dev/staging/prod 配置和本地数据容器完全隔离，生产包不能指向测试服务
- [ ] 配置无效、SecureStore 不可用和依赖装配失败有确定错误页
- [ ] BootstrapHost 首帧不等待 SecureStore、K103/K104 或非关键第三方 SDK
- [ ] 本地 SessionBundle 只形成恢复候选，不直接开放受保护路由
- [ ] 启动 SingleFlight 防止重复初始化、多容器和迟到结果回写
- [ ] 自动化测试覆盖每个关键阶段的成功、失败、重试和生命周期变化
- [ ] 启动日志不含 Token、手机号、账号、原始设备硬件标识或配置全文
- [ ] Android/iOS 冷启动、热启动、前后台恢复和升级安装完成真机冒烟

实现项在编码完成后逐项执行；当前勾选只表示文档内容已具备评审条件。
