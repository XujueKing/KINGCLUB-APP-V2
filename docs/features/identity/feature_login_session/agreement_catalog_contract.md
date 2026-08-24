# 未登录协议目录读取契约

- 文档状态：`Implemented / Approved for Development`
- 影响页面：手机号登录页、验证码页、协议确认页
- 当前结果：未登录客户端已有 K107 读取当前发布版本和正文，登录仍由服务端按同一目录复核

## 1. 已确认边界

- 客户端提交的 `terms/privacy` 版本必须与服务端当前强制发布目录一致。
- 客户端必须实际展示对应内容，不能硬编码一个版本号后直接生成同意记录。
- 协议正文属于公开内容，但目录响应仍需防篡改、可审计并与登录校验使用同一权威数据源。
- 正式正文和首个版本未提供不阻塞接口开发，但阻塞生产上线。

## 2. 已批准实现

用户于 2026-08-24 批准新增 `K260824000107 auth.agreements.current`，服务端提交 `business/kingclub-v2 / 9e7ee5c` 已实现，提交 `d9929ff` 补齐旧协议版本不消耗短信 challenge 的密文验收：

| 项目 | 已批准值 |
|---|---|
| 鉴权 | handshake，无用户会话 |
| 写操作 | 否 |
| 请求 | `clientAppCode=kingclub`、`clientType=android|ios`、`locale=zh-CN` |
| 返回 | 当前强制协议数组、目录版本、缓存截止时间 |
| 缓存 | 响应给出 5 分钟截止时间；登录前仍按服务端当前版本校验 |
| 隐私 | 请求/响应不含手机号、账号、设备广告标识或凭据 |

建议响应：

```json
{
  "catalogVersion": "opaque-public-version",
  "expiresAt": "ISO-8601",
  "agreements": [
    {
      "agreementCode": "terms",
      "version": "published-version",
      "title": "用户协议",
      "publishedAt": "ISO-8601",
      "contentDigest": "sha256-hex",
      "contentFormat": "markdown",
      "content": "published-content"
    },
    {
      "agreementCode": "privacy",
      "version": "published-version",
      "title": "隐私政策",
      "publishedAt": "ISO-8601",
      "contentDigest": "sha256-hex",
      "contentFormat": "markdown",
      "content": "published-content"
    }
  ]
}
```

V1 内联返回受控 Markdown，单份正文限制 1～262144 字节，避免外部 URL 域名、重定向、离线摘要校验和跨端 WebView 差异。Flutter 渲染层必须禁用原始 HTML/脚本，并按后续内容安全文档执行链接白名单。

## 3. 登录一致性

1. 客户端读取目录并展示正文。
2. 用户明确同意确切 `agreementCode + version + contentDigest`。
3. 短信登录只提交 `agreementCode + version`；服务端从权威目录重新取得摘要并写追加式同意记录。
4. 若读取后版本变化，登录返回既有稳定错误 `AUTH_CONSENT_VERSION_INVALID`。Node 在短信证明验证/消费前校验协议版本，因此该失败不消费 challenge；客户端重新读取目录后可在证明有效期内重新提交。
5. 客户端重新读取目录、清除旧勾选并要求重新同意。

## 4. 不采用的默认方案

- 不把协议版本永久硬编码在 Flutter 源码。
- 不由客户端自行拼接协议 URL。
- 不在短信发送响应中夹带协议正文；短信幂等与公开内容缓存生命周期不同。
- 不使用用户勾选布尔值替代确切版本和内容摘要。

## 5. 开发准入

- [x] 用户确认新增 K107 作为协议目录权威读取接口
- [x] interfaceId、请求/响应、错误码、Markdown、256 KiB 上限和 5 分钟缓存评审
- [x] migration 022、internal 执行器、专项测试和隔离密文 E2E 可供 Flutter 集成
- [x] 手机号页、验证码页和协议确认页均已引用同一目录与版本变化契约

## 6. 验证证据

- 全新 MySQL 8.4 隔离库从 migration 001 连续实迁至 022。
- K107 通过真实 ECDH/AES/HMAC 密文调用，正常 terms/privacy、非法语言拒绝、旧协议版本拒绝且 challenge/失败次数不变、摘要篡改失败关闭和身份敏感字段零返回均通过。
- 本机 `kingclub_v2` 已增量应用 022，并核对四个新增列及 K107 的 `internal + handshake + enabled` 元数据。
- 服务端完整质量门禁为 37 个测试文件、133 项测试通过。
