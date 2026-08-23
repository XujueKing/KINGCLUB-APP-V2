# 物业服务端与 JNGJ-WX 认证复用审计

- 文档状态：In Review
- 审计基线：`ccsop-service main / f543854`
- 参考分支：`business/zhuzhou-property-regulation-v1 / 6678112`
- 参考客户端：`JNGJ-WX main`
- 审计方式：只读源码、migration、测试与接口契约对比

## 1. 审计结论

- **已确认事实**：物业分支的认证能力与后续物业业务共处一条大提交链，不能整体合并或直接 cherry-pick 到 KingClub。
- **已确认事实**：短信挑战、手机号登录或注册、Refresh Token 轮换、微信登录、身份绑定和登录初始化已经在物业分支形成可运行参考。
- **已确认事实**：JNGJ-WX 已实现握手、密文超级接口、登录 SingleFlight、会话恢复、Refresh Token 轮换、敏感日志脱敏和加密 WebSocket 客户端。
- **当前建议**：按组件和契约重新移植通用能力，KingClub 使用自己的 migration、Routine、业务线配置和 `K...` 接口编号。
- **当前建议**：第一批只落地手机号短信登录、会话刷新、当前用户、注销、撤销其他会话和 WebSocket 会话撤销；微信登录作为后续独立功能评审。

## 2. 服务端可复用清单

| 参考资产 | 可复用内容 | KingClub 处理方式 | 结论 |
|---|---|---|---|
| `021_sms_foundation.sql` | 短信供应商、场景路由、挑战、发送审计模型 | 重新编号 migration，改为 KingClub 场景和目录登记 | 迁移语义 |
| `026_mobile_login_or_register_foundation.sql` | 验证手机号身份、创建账号、发放 API Key/Session 的事务结构 | 重写为 KingClub 单设备事务，并创建 App 成员 | 迁移语义 |
| `027_auth_business_bootstrap_foundation.sql` | 登录成功后按 App 路由业务初始化 | 目标改为 KingClub 最小成员摘要，不带物业房屋逻辑 | 部分迁移 |
| `028_auth_rotate_session_identity_scope.sql` | 会话/API Key 原子轮换 | 与 Refresh Token 版本和单设备范围合并设计 | 迁移语义 |
| `031_refresh_session_foundation.sql` | 当前/上一版本 Token、并发刷新和重用检测 | 保留轮换与重用撤销规则，重新实现测试 | 优先迁移 |
| `035_login_identity_management_foundation.sql` | 身份快照、绑定/解绑身份、可信会话用户注入 | 第一批仅采用快照与可信上下文，绑定管理后置 | 部分迁移 |
| `sms-router-adapter` 与供应商适配器 | 供应商路由、限流、挑战审计 | 抽取通用模块，配置使用 KingClub 独立密钥和场景 | 可迁移 |
| `mobile-login-crypto/repository` | 手机号规范化、HMAC 指纹、密文保存、数据库边界 | 保留算法和边界，使用 KingClub 独立密钥 | 可迁移 |
| `internal-auth-executor` | 服务端生成 Session/API Key/Refresh Token，Zod 校验 | 拆出 KingClub 所需动作，禁止复制整个大执行器 | 部分迁移 |
| 认证测试 | 非法参数、Token 不入库明文、并发刷新、微信冲突 | 改成 KingClub 接口编号并补单设备/跨 App 测试 | 必须迁移 |

## 3. 明确不复用的服务端内容

- 物业业务初始化、房屋、小区、组织、收费、钱包、控制台和物业权限逻辑。
- 物业接口编号 `S260...` 及接口分类节点。
- `zhuzhou-property` 业务线配置、AppCode、微信应用配置和生产适配器凭据。
- Web QR 登录、Web SSO、密码登录和物业控制台 Cookie 会话；它们不属于 KingClub 第一批移动端范围。
- 直接复制物业 migration 编号 018 之后的完整链路。
- 让客户端传入 `userAccount`、`businessLine`、角色、scope 或对象所有者作为可信值。

## 4. JNGJ-WX 可迁移到 Flutter 的模式

| JNGJ-WX 资产 | Dart/Flutter 对应设计 | 结论 |
|---|---|---|
| `CcsopClient` | 集中管理握手/会话密文请求、错误解包和超时 | 迁移设计 |
| `NobleSecureChannel` | ECDH P-256、HKDF、AES-GCM、HMAC 与服务端密钥版本校验 | 按官方 Dart 加密库重写并使用服务端测试向量 |
| `SingleFlight` | 合并并发握手、登录和刷新请求 | 必须保留 |
| `AuthService` | 匿名、恢复、登录、已认证状态编排 | 迁移状态机，不复制小程序 API |
| `SessionRepository` | 会话快照版本、完整性校验、原子替换和清理 | Flutter 使用 Keychain/Keystore 安全存储 |
| `SafeLogger` | 按字段名递归脱敏 | 必须保留并扩展手机号、验证码和设备标识 |
| `CcsopWebSocketClient` | 连接签名、方向密钥、帧加密、序号和事件分发 | 迁移协议与测试向量 |

## 5. 不能原样复制的客户端行为

1. JNGJ-WX 的 `logout()` 只清本地数据，没有先调用服务端撤销会话；KingClub 必须提供幂等服务端注销接口。
2. JNGJ-WX 会话最终保存到微信同步存储；Flutter 必须保存到 Keychain/Keystore，不得使用普通 SharedPreferences。
3. 当前 WebSocket 客户端没有完整的指数退避、前后台切换、网络变化、心跳超时和 `auth.session.revoked` 处理。
4. 当前客户端没有把旧设备被顶下线作为独立认证状态，也没有验证跨 App 不互踢。
5. 当前接口常量使用物业 `S260...` 编号；KingClub 页面和 ViewModel 不得接触裸接口编号。

## 6. 建议移植顺序

1. 注册 `kingclub` 业务线和独立适配器配置骨架。
2. 移植通用短信路由、挑战模型及测试，不写真实供应商凭据。
3. 建立 KingClub 身份/App 成员/单设备会话 migration。
4. 拆出最小 `KingclubAuthExecutor`，完成短信登录与刷新。
5. 建立服务端可信请求上下文和对象级权限测试。
6. 增加注销、旧会话撤销事件和 WebSocket 主动断开。
7. 根据本目录接口契约生成 Dart 客户端方法，再建设登录页面文档。

## 7. 复用准入门槛

- 每个移植对象有独立递增 migration、目录登记、接口登记和双语注释。
- KingClub 空白数据库可以从 `001` 基线完整重建。
- 不依赖物业业务表、物业 AppCode 或物业接口编号。
- 单设备、跨 App 隔离、Token 重用、并发刷新和旧连接关闭均有自动化测试。
- 服务端和客户端日志不出现手机号、验证码、API Key、Refresh Token 或会话完整标识。
