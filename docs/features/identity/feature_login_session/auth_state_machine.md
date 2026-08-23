# KingClub V2 登录鉴权状态机

- 文档状态：In Review
- 客户端范围：Flutter iOS/Android
- 服务端范围：`business/kingclub-v2`

## 1. 客户端状态

| 状态 | 含义 | 允许动作 |
|---|---|---|
| `unknown` | App 刚启动，尚未读取安全存储 | 仅执行启动恢复 |
| `anonymous` | 没有可用会话 | 握手、发送验证码、登录 |
| `handshaking` | 正在建立临时安全通道 | 等待或取消，不重复发起 |
| `challengeSent` | 验证码已发送 | 提交验证码、按冷却时间重发 |
| `authenticating` | 登录事务执行中 | 禁止重复提交 |
| `authenticated` | 服务端确认会话有效 | 调用业务接口、连接 WebSocket |
| `refreshing` | 会话即将过期，正在轮换 | 其他受保护请求等待同一刷新结果 |
| `revoked` | 被新设备、风控、冻结或管理员撤销 | 清除凭据并展示原因 |
| `expired` | Session 或 Refresh Token 到期 | 清除凭据并重新登录 |
| `locked` | 验证码尝试过多或账号暂时锁定 | 等待服务端给出的恢复时间 |

握手、登录、刷新分别使用独立 SingleFlight key；页面不得自行维护第二套认证状态。

## 2. 首次短信登录或注册

```text
anonymous
  -> handshaking
  -> challengeSent
  -> authenticating
  -> authenticated
```

1. 客户端生成或读取稳定设备实例 ID；只传受控设备标识，不传用户身份。
2. 完成 ECDH 握手，通过密文调用发送验证码接口。
3. 服务端按手机号指纹、设备、IP、业务线和场景限流，返回 challengeId 与冷却时间。
4. 客户端密文提交 challengeId、手机号、验证码、设备信息和已同意协议版本。
5. 服务端在一个事务内消费挑战、创建/查找统一身份、建立 KingClub 成员、撤销旧 KingClub 会话并签发新凭据。
6. 客户端原子写入 Keychain/Keystore；只有写入成功后才进入 authenticated。
7. 客户端调用 `auth.session.me` 复核最小身份和成员状态，再建立 WebSocket。

失败时不得保留半套凭据；验证码错误回到 challengeSent，挑战过期回到 anonymous 或重新发送。

## 3. 启动恢复与刷新

```text
unknown
  -> 本地无完整会话 -> anonymous
  -> 会话仍有安全余量 -> 调用 me 复核 -> authenticated
  -> 接近/超过访问期限 -> refreshing -> authenticated
  -> 刷新失败或重用命中 -> expired/revoked -> anonymous
```

- 本地会话仅表示“可能可恢复”，不能直接授予业务权限。
- 同时到达的受保护请求共用一个刷新任务；刷新完成后仅重放明确标记可安全重试的请求。
- Refresh Token 每次成功使用后轮换并递增版本，客户端必须原子替换整套凭据。
- 服务端发现上一版本 Token 被再次使用时，撤销该会话和 API Key，返回 `AUTH_REFRESH_REUSE_DETECTED`。
- 并发刷新中只有一个事务成功；其他请求收到并发冲突后重新读取安全存储，不再次使用旧 Token。

## 4. 单设备登录与顶号

唯一范围：`userAccount + clientAppCode=kingclub`。

1. 新设备登录事务锁定该范围的活动会话。
2. 旧 Session 标记 revoked，原因为 `new_device_login`；旧 API Key 同时撤销。
3. 创建新 Session/API Key 后提交事务。
4. 提交后通过 Redis Pub/Sub 或现有通知总线发布 `auth.session.revoked`，目标是旧 `sessionId`。
5. WebSocket Hub 立即关闭本机或其他实例上的旧连接；如果事件投递失败，旧凭据在下一次 API/重连验证时仍必须失败。
6. 旧客户端收到事件后立即停止请求、关闭 Socket、清除安全存储，并显示“账号已在其他设备登录”。

物业 App 的会话不在 KingClub 数据库和 `clientAppCode` 范围内，不得被撤销。

## 5. 主动注销

1. 客户端调用幂等 `auth.session.logout`，身份来自服务端会话上下文，不提交 userAccount。
2. 服务端撤销当前 Session 和 API Key，发布撤销事件并返回 revokedAt。
3. 客户端无论服务端响应成功、已撤销或 Token 已失效，都关闭 WebSocket 并清除本地凭据。
4. 如果设备完全离线，只能完成本地退出；UI 必须提示服务器会话可能持续到短期 TTL，不能伪称远端已撤销。

## 6. WebSocket 会话撤销

事件最小契约：

```json
{
  "eventType": "auth.session.revoked",
  "data": {
    "sessionId": "opaque",
    "reason": "new_device_login",
    "revokedAt": "ISO-8601"
  }
}
```

该事件仍走现有加密帧、签名和递增序号。客户端不 ACK 后继续使用会话；收到后必须立即执行本地撤销。断线期间错过事件时，由下次 API、重连鉴权或 `auth.session.me` 补偿。

## 7. 异常与风控路径

| 场景 | 服务端结果 | 客户端状态 |
|---|---|---|
| 验证码错误 | 增加尝试次数，返回剩余次数 | challengeSent |
| 验证码过期/已消费 | 拒绝重放 | anonymous |
| 尝试次数达到上限 | challenge locked | locked |
| 账号 disabled/deleted/merged | 不签发新会话 | revoked 或人工处理页 |
| KingClub 成员 suspended/rejected | 可返回受限身份摘要，不授予业务权限 | authenticated-limited（页面另行设计） |
| Refresh Token 版本错误 | 拒绝并记录审计 | refreshing 后重新判断 |
| Refresh Token 重用 | 撤销 Session/API Key | revoked |
| 新设备登录 | 新会话成功，旧会话撤销 | 新端 authenticated，旧端 revoked |
| WebSocket 签名/序号失败 | 丢弃帧并关闭异常连接 | API 会话状态不由 Socket 单独决定 |

## 8. 待评审参数

- Access/API Key TTL、Refresh Token TTL、提前刷新窗口。
- 验证码 TTL、重发冷却、日限额和最大尝试次数。
- 新设备顶号是否只显示结果，还是登录前增加提示；安全撤销本身立即生效。
- 账号冻结、成员受限和 KYC 未完成时的可访问接口白名单。
