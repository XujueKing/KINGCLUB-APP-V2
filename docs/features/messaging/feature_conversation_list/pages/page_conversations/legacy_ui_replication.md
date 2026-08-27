# 旧版聊天列表 UI 复刻规范

- Scope ID：`KC-P-022`
- 文档状态：`Approved for Development`
- 设计版本：`Legacy Conversations Replica v1`
- 复刻依据：旧版 `pages/index/index` + 用户于 2026-08-26 提供的聊天截图
- 数据阶段：仅本地 Fake，不连接 WebSocket、超级接口或服务器

## 已确认事实

- 消息分支顶部保留相邻的 `通讯录 / 聊天` 两个选项。
- 用户要求现有通讯录主体 UI 不变，只在旁边增加“聊天”选项。
- 聊天选中态使用香槟金亮色、较大字号和粗体；通讯录为低透明度未选中态。
- Flutter App 不绘制截图中的微信右上角宿主胶囊，也不绘制手机外框和系统状态栏。
- 底部仍使用已批准的旧版五 Tab 胶囊，消息 Tab 在该分支保持选中。
- 旧版聊天搜索输入节点仍在源码中，但通过 `wx:if="{{0==1}}"` 硬关闭；本复刻版本不得在正常首屏自行恢复该搜索栏。

## 截图基准内容

```text
[ + ]             通讯录   聊天

[列表图标]  折叠置顶聊天

[蓝色 King 头像]  KING CLUB                 08月23日
                  收到50枚金币
--------------------------------------------------
```

## 视觉规则

- 页面背景纯黑。
- 顶部左侧使用细圆圈加号，点击进入添加好友 Fake 意图。
- 顶部两项居中相邻排列；聊天选中、通讯录未选中。
- 置顶折叠栏使用 `#C9B69E20` 深棕半透明背景，圆角约 `10dp`，左侧列表/置顶图标，文字 `折叠置顶聊天`。
- 会话行高约旧版 `140rpx`，头像为蓝紫圆形 KingClub 品牌头像。
- 主标题逐字为 `KING CLUB`；摘要逐字为 `收到50枚金币`；日期逐字为 `08月23日`。
- 标题为浅灰白，摘要与日期约 40% 白色，行底为低透明度香槟金分割线。
- 首个 Fake 场景只显示截图中的一条系统会话，其余区域保持纯黑留白。

## 交互

- 点击 `通讯录`：回到现有通讯录，不重建其搜索、快捷入口、分组和状态。
- 点击 `聊天`：显示聊天列表并保留滚动位置。
- 点击折叠栏：切换 `折叠置顶聊天 / 1 个置顶聊天`，折叠时隐藏置顶会话。
- 点击 `KING CLUB`：进入本地 Fake 单聊/系统会话预览；不得连接 WebSocket。
- 点击加号：复用现有 `addFriend` Fake 意图。
- 好友会话左滑沿用旧版三段操作区的灰/橙/红层级；V2 Mock 将首项调整为“标为已读/未读”，第二项用于“置顶/取消置顶”，第三项为“删除”。
- 长按提供与左滑一致的底部菜单，避免只有手势才能完成操作。
- 删除保留旧版“确认删除并清空记录？”二次确认文案，但仅移除内存 Fake 会话。
- 下拉刷新沿用旧版 `refresher-enabled="true"` 交互；Fake 失败时保留原列表并显示窄幅离线提示，重试成功后收起。
- 唯一好友会话被移除后仍保留 KING CLUB 系统入口，其余区域保持旧版纯黑留白。
- 长按菜单允许切换只读摘要、失效摘要和恢复正常 Fake 状态；这些演示动作不在旧版正常首屏增加常驻入口。
- 只读/失效行沿用同一头像、行高、日期列和分隔线，只替换摘要文案并清除未读，避免异常状态破坏旧版列表结构。

## Fake 数据

```text
conversationId: fake-system-kingclub
title: KING CLUB
preview: 收到50枚金币
dateLabel: 08月23日
pinned: true
unreadCount: 0
muted: false
```

好友 Fake 会话初始使用 `unreadCount: 2`、`pinned: false`，用于完整演示未读、置顶、折叠和删除状态。

## 验收

- [x] 通讯录主体 UI 与当前实现保持一致。
- [x] 顶部可在通讯录和聊天之间双向切换。
- [x] 聊天页首屏结构、文案、颜色和留白与截图一致。
- [x] KING CLUB 会话、置顶折叠和加号都有 Fake 反馈。
- [x] 消息底栏选中态保持不变。
- [x] 无网络、WebSocket、真实消息或服务器调用。
- [x] 好友会话未读数字、进入已读、手动标记未读可演示。
- [x] 左滑三段操作与长按等价菜单可演示。
- [x] 置顶分组、折叠归属和删除二次确认可演示。
- [x] 正常首屏不出现旧源码已硬关闭的搜索栏。
- [x] 下拉刷新失败保留列表，重试后恢复 ready。
- [x] 删除唯一好友后只保留 KING CLUB 与纯黑留白。
- [x] 关系结束后的只读摘要阻止发送入口。
- [x] 会话失效阻止错误导航并提供本地恢复/返回通讯录。
- [x] 离线状态显示固定 Fake 缓存时间，正常首屏不受影响。

## 设备验收记录

- 日期：2026-08-26
- 设备：Android API 37 模拟器，1080 × 2400
- 截图：[android_chat_mock_latest.png](android_chat_mock_latest.png)
- 刷新状态：[离线保留](android_conversation_offline_refresh.png)、[重试恢复](android_conversation_refresh_recovered.png)
- 异常状态：[长按场景菜单](android_conversation_scenario_menu.png)、[关系结束摘要](android_conversation_relationship_readonly.png)、[只读阻断](android_conversation_relationship_readonly_dialog.png)、[会话失效](android_conversation_invalid.png)、[失效恢复](android_conversation_invalid_dialog.png)、[恢复正常](android_conversation_invalid_recovered.png)
- 自动验证：`flutter analyze` 无问题；会话管理组件测试和整套 Widget 测试通过。
