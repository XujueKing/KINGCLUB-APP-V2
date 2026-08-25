# 内容浏览与播放状态

```text
进入发现 -> 加载首屏 -> 当前项封面 -> 可播放 -> 播放
                              |-> 缓冲 -> 恢复/失败
上滑 -> 暂停旧项 -> 激活新项 -> 受控预加载下一项
离开分支/后台 -> 全部暂停 -> 恢复后重验当前内容
```

## 状态原则

- Feed：`initialLoading/content/empty/refreshing/loadMore/error/offline/sessionInvalid`。
- Item：`posterOnly/preparing/playing/paused/buffering/ended/mediaError/unavailable`。
- 同时最多一个 item 处于 playing；页面不可见时必须为零。
- 迟到的 prepare/play 回调必须校验当前 ContentRef 与 generation，不能唤醒已离屏视频。
- 播放失败只影响当前项；连续失败达到阈值后停止自动推进并提示重试。
- 恢复前台必须重验媒体 URL 和内容可见性，不继续使用已过期地址。
