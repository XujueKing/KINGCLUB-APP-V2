# 用户主页旧版审计

- 文档状态：`In Review`

| 旧实现 | 风险 | V2 取舍 |
|---|---|---|
| `friendinfo` | 扫码来源页，URI 携带对方账号 | 合并为统一用户主页 |
| `newfriendInfo` | 信任 URI 中申请状态、留言和来源 | 只传 requestRef 后权威读取 |
| `userInfo` | 同时含关注、好友、聊天、分组、内容和隐私 | 只呈现批准资料与 allowedActions |
| `S231202506270743` | 同一接口返回自己的/他人的大量 JSON 字符串 | V2 独立 `PublicMemberProfile` 投影 |
| copyBind | 可复制永久账号 | 删除 |

旧展示字段只用于决定删除/保留，不作为 V2 新接口字段基线。
