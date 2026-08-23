# 未登录协议目录读取契约

- 文档状态：`Draft / Pending Decision`
- 影响页面：手机号登录页、验证码页、协议确认页
- 当前问题：服务端能校验协议版本，但未登录客户端没有读取当前发布版本和正文的契约

## 1. 已确认边界

- 客户端提交的 `terms/privacy` 版本必须与服务端当前强制发布目录一致。
- 客户端必须实际展示对应内容，不能硬编码一个版本号后直接生成同意记录。
- 协议正文属于公开内容，但目录响应仍需防篡改、可审计并与登录校验使用同一权威数据源。
- 正式正文和首个版本未提供不阻塞接口开发，但阻塞生产上线。

## 2. 当前建议

新增 `K260824000107 auth.agreements.current`：

| 项目 | 建议 |
|---|---|
| 鉴权 | handshake，无用户会话 |
| 写操作 | 否 |
| 请求 | `clientAppCode=kingclub`、`clientType=android|ios`、`locale=zh-CN` |
| 返回 | 当前强制协议数组、目录版本、缓存截止时间 |
| 缓存 | 可短期缓存公开目录；登录前仍按服务端当前版本校验 |
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

V1 优先内联返回受控 Markdown，避免外部 URL 域名、重定向、离线摘要校验和跨端 WebView 差异。正文大小上限、允许的 Markdown 子集、链接白名单和无脚本渲染必须在实现契约中冻结。

## 3. 登录一致性

1. 客户端读取目录并展示正文。
2. 用户明确同意确切 `agreementCode + version + contentDigest`。
3. 短信登录只提交 `agreementCode + version`；服务端从权威目录重新取得摘要并写追加式同意记录。
4. 若读取后版本变化，登录返回稳定的 `AUTH_AGREEMENT_VERSION_OUTDATED`，不消费或允许重新使用 challenge 的规则必须在实现前确定。
5. 客户端重新读取目录、清除旧勾选并要求重新同意。

## 4. 不采用的默认方案

- 不把协议版本永久硬编码在 Flutter 源码。
- 不由客户端自行拼接协议 URL。
- 不在短信发送响应中夹带协议正文；短信幂等与公开内容缓存生命周期不同。
- 不使用用户勾选布尔值替代确切版本和内容摘要。

## 5. 开发准入

- [ ] 用户确认权威来源：新增 K 接口或指定已有内容服务
- [ ] interfaceId、请求/响应、错误码、正文格式和大小上限评审
- [ ] Mock 契约或服务端实现可供 Flutter 集成测试
- [ ] 手机号页、验证码页和协议确认页同步引用同一契约
