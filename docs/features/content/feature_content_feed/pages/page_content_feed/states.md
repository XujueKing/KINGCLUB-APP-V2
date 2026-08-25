# 内容流页状态

| 状态 | UI/动作 |
|---|---|
| `initialLoading` | 深色骨架，不自动出声 |
| `contentPlaying/contentPaused` | 当前项唯一播放/暂停 |
| `buffering` | 保留封面与明确进度 |
| `mediaError` | 当前项重试/跳过 |
| `empty` | 无内容与返回首页建议 |
| `refreshing/loadingMore/loadMoreError` | 独立分页状态 |
| `contentUnavailable` | 停止播放、通用说明 |
| `lowData/offlinePosterOnly` | 不预加载视频 |
| `branchInactive/background` | 零播放实例 |
| `sessionInvalid` | 释放媒体并登录 reset |

未知审核/可见状态按不可播放处理。
