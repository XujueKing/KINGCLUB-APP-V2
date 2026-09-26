# 群媒体编码参数兼容修正

双机群通话在媒体建立阶段出现 15 秒超时。检查固定依赖 mediasfu_mediasoup_client 0.1.4：Transport 的异步 FlexQueue 在非 debug 模式只调用可选 errback，而 produce 未提供该 errback；底层异常可被吞掉，最终由应用超时保护退出。

发现确定的参数缺口：UnifiedPlan.send 对非空 encodings 的第一项直接读取 `scalabilityMode!`。应用此前仅设置 maxBitrate，该字段为空。现为音频和视频的单流发布明确传入 `L1T1`，保持既有码率与单层编码，不修改共享 pub-cache 依赖。

Transport 测试夹具增加与固定 SDK 对齐的非空编码要求。28 项 native_group_call_media 测试通过，两个变更 Dart 文件 analyze 无问题。

尚未实机证明此修正解决全部连接问题。诊断 debug 包构建因 D 盘空间不足失败，未安装到 A；A 仍为此前 profile 包。本次产生的 debug merged_native_libs 和 assets 中间目录已转存 C 盘，未删除用户文件。后续需恢复足够构建空间，再集中构建、验证发布和后台保持；不能将此节点标为群通话验收完成。

后续构建空间已恢复：聊天隔离目录 build 转存至 C 盘并保留原路径 junction，未能跨盘移动的 Windows 长路径中间产物另行保留。修复 profile APK 构建成功（95.9 秒，146.8 MB），SHA256 `37044AD15C135F143AC513A8C2EAEBDC4DE2A6140E7AF9A237078DC798003E08`，A 覆盖安装返回 Success。尚待新包群媒体连接复测；B 原聊天预览版不含此修正，B 正式包尚未验证登录。
