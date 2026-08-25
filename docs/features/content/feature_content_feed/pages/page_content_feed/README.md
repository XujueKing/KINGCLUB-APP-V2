# 短视频/作品流页

- Scope ID：`KC-P-013`
- 文档状态：`Approved for Development`
- M0 范围：`In Release Scope`
- 所属功能：[短视频与作品浏览](../../README.md)
- 旧版来源：`index` 视频 tab + `openVideo`
- 路由：`ContentFeedRoute`，`/discover`
- 设计版本：`Content Feed Wireframe v1`
- 最后更新：2026-08-25

## 用户任务与线框

在“发现”主分支持续浏览同城作品，并进入作者主页。

```text
发现
┌──────────────────────────┐
│                          │
│       视频/图片内容       │
│       [缓冲/重试]         │
│                          │
│ [头像] 昵称               │
│ 作品文案（最多三行）       │
│ #公开标签 · 株洲/门店级    │
│                    [静音] │
└──────────────────────────┘
[首页] [消息] [扫码] [发现] [我的]
```

- 不显示发布、点赞、评论、收藏、分享和关注按钮。
- 播放状态不能只靠图标；读屏提供“已暂停/正在缓冲/静音”等文本语义。
- 200% 字体下作者与文案区域可滚动/折叠，不遮挡系统导航和底部 Shell。

状态见 [states.md](states.md)，交互见 [interactions.md](interactions.md)，验收见 [acceptance.md](acceptance.md)。
