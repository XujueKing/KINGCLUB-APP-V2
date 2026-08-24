# 协议确认页状态与错误映射

## 1. 页面模式

| 模式 | 入口 | 是否允许确认 | 返回行为 |
|---|---|---:|---|
| `readOnly` | 手机号页点击用户协议或隐私政策 | 否 | 返回并保留来源页内存表单 |
| `loginRecovery` | K102 返回 `AUTH_CONSENT_VERSION_INVALID` | 是 | 同意后回验证码页；拒绝则销毁登录流程 |

页面不能根据是否显示按钮自行推断模式；模式来自类型化、仅内存的导航契约。`loginRecovery` 还必须解析有效 `loginFlowId`，不能由深链构造。

## 2. 页面状态

| 状态 | 含义 | 允许动作 |
|---|---|---|
| `loadingCatalog` | K107 首次读取 | 等待、退出 |
| `readyReadOnly` | 两份协议通过完整性检查 | 切换标签、滚动、关闭 |
| `readyRecovery` | 目录完整且 challenge 仍有效 | 阅读、勾选、同意或拒绝 |
| `refreshingCatalog` | 缓存到期或前台恢复后刷新 | 保留阅读位置，禁用同意 |
| `versionChanged` | 目录版本与当前快照不同 | 清除勾选、提示更新、重新阅读 |
| `catalogUnavailable` | K107 失败或两份协议不完整 | 重试或退出，不允许同意 |
| `contentRejected` | Markdown 摘要、大小或安全结构不合法 | 失败关闭并记录稳定错误分类 |
| `challengeExpired` | 恢复模式的短信 challenge 已到期 | 销毁流程并回手机号页 |
| `acceptingLocally` | 正在原子替换内存 ConsentSnapshot | 防重复点击 |
| `acceptedLocally` | 新快照已写入内存 | replace 回验证码页 |

## 3. 目录校验

- 响应必须包含且只接受当前强制 `terms`、`privacy` 两项，代码不可由标题推断。
- 每项必须具有非空标题、版本、`publishedAt`、64 位小写 SHA-256、`contentFormat=markdown` 和 1～262144 字节正文。
- 客户端对收到的正文重新计算 SHA-256 并与 `contentDigest` 比较；失败时不得展示同意按钮。
- `catalogVersion` 与两份协议字段共同组成不可变页面 generation。任一刷新结果变化都递增 generation、清除勾选并忽略旧异步结果。
- `expiresAt` 是缓存重验截止点，不是法律协议失效时间；客户端不得伪造更长缓存。

## 4. Markdown 安全边界

- 允许标题、段落、列表、引用、强调、代码文本和受控链接等基础 Markdown；禁止原始 HTML、脚本、iframe、表单、内嵌媒体和 `javascript/data/file` URI。
- HTTPS 外链必须经过后续 networking/navigation foundation 的域名白名单与离站确认；不在 WebView 中注入登录 Cookie、API Key 或自定义 JavaScript。
- 解析器遇到不支持或危险结构时整体进入 `contentRejected`，不能静默删除一部分正文后仍允许用户同意。
- 正文可仅在内存或受版本/摘要约束的公开缓存保存，不与用户身份、手机号或登录凭据关联。

## 5. 错误映射

| 结果 | 页面状态 | 规则 |
|---|---|---|
| K107 成功且完整 | `readyReadOnly|readyRecovery` | 按入口模式显示控件 |
| `AUTH_AGREEMENT_CATALOG_UNAVAILABLE` | `catalogUnavailable` | 显示“协议暂时无法加载”，失败关闭 |
| 明确离线/超时 | `catalogUnavailable` | 未过期且已验摘要的内存缓存可只读；恢复确认必须在有效缓存内 |
| 版本/摘要变化 | `versionChanged` | 清除勾选，两份协议一起形成新快照 |
| challenge 到期 | `challengeExpired` | 不再返回验证码页继续提交 |
| 路由模式或 flowId 非法 | 安全退出 | 清理可疑上下文，replace 到手机号页 |

页面不透传服务端堆栈、数据库字段或内部内容发布信息。
