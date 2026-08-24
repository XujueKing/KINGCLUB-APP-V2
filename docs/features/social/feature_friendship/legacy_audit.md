# 好友申请旧版审计

- 文档状态：`In Review`
- 审计基线：`KingClub-app master / 505d222 / 1.1.37`

| 旧页面/接口 | 发现 | V2 取舍 |
|---|---|---|
| `addfriend` | 永久账号二维码、手写 URL 解析、展示会员号 | 入口页转交 Safe Scanner 与 Personal QR |
| `newfriend` / S...668 | 列表覆盖式页码加载，状态用数字 | cursor + 明确方向/状态枚举 |
| `newfriendInfo` / S...669 | 路由信任 status/remarks/source，数字 typeId 处理 | 只传申请引用，详情重新读权威状态 |
| `createfriendinfo` / S...656 | URI 带双方账号，提交后另发 WebSocket | 幂等命令；通知是服务端结果事件 |
| `friendinfo` | 扫码后直接以永久账号查用户 | token 兑换一次性预览引用 |

旧接口只作行为证据，不复用 ID、数字状态或客户端身份参数。
