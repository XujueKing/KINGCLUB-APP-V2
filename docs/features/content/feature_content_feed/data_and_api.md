# 内容流数据与 Fake 契约

## 引用和展示模型

- `ContentRef { refId, generation }`
- `MediaPlaybackRef { refId, expiresAt }`
- `AuthorPreview { SocialTargetRef, nickname, avatar, visibility }`
- `ContentCardView`：ContentRef、媒体类型、封面、播放引用、文案摘要、公开标签、作者投影、状态
- `FeedPage { items, nextCursor, asOf }`

## UI 阶段 ports

- `ContentFeedPort.loadFirst()/refresh()/loadMore(cursor)`
- `ContentFeedPort.resolve(contentRef)`
- `MediaPlaybackPort.prepare(playbackRef)`
- `MediaPlaybackPort.pause()/dispose()`
- `PlaybackPreferencePort.load/saveMutedPreference()`

UI/Mock 阶段使用 Fake cursor 和 Fake player clock；不得通过页面直接下载 URL 或调用超级接口。未来真实播放器 adapter 必须保持单播放实例和生命周期契约。
