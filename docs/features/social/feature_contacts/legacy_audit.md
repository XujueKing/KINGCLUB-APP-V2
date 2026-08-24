# 通讯录旧版审计

- 文档状态：`In Review`
- 审计基线：`KingClub-app master / 505d222 / 1.1.37`

| 旧实现 | 发现 | V2 取舍 |
|---|---|---|
| `index.wxml` 通讯录 swiper | 和聊天列表共用物理页面和状态 | 拆为 KC-P-014 独立页面 |
| `S231202503230666` | 返回好友、搜索状态、申请数和动态 tabData | 拆成稳定联系人投影；服务端不得控制导航 |
| `friends_bindtap` | URI 拼接永久 `userAccount` | 改用内存 `SocialTargetRef` |
| A～Z 索引 | 固定英文字符且缺少 `N/#` 等边界 | 使用服务端 sectionKey + `#` 兜底 |
| 搜索框 | 同一变量同时服务聊天与好友 | 通讯录拥有独立 query、状态和取消行为 |

旧接口 ID、字段和 JSON 字符串只作审计证据，不复用为 V2 客户端契约。
