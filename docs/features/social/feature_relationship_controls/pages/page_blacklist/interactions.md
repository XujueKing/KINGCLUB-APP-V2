# 黑名单页交互

- 搜索只匹配清洗后的公开昵称，300ms 防抖；不匹配账号/手机号。
- 点击行发出 `openUserProfile(targetRef)`；点击解除先显示“不会恢复好友”的确认。
- 解除使用 expected relationshipVersion + 幂等键；结果未知先查询。
- 分页失败不清空首屏；离线缓存不能执行解除。
- 从其他设备已解除时按权威结果移除，并显示稳定提示。
- token、targetRef 和昵称不写入分析事件或错误日志。
