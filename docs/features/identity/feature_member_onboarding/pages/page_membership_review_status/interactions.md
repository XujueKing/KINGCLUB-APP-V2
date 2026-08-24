# 会员审核状态页交互

- 下拉/按钮刷新使用 SingleFlight，并展示最近更新时间；不做高频轮询。
- approved 点击后重新复核当前 snapshot，再 reset Shell；迟到 revoked/suspended 优先。
- changesRequired 只把服务端枚举映射到本地 allowlist 页面，不执行 URL。
- 重提按钮在 `canResubmit=false` 或冷却未到时禁用并说明可用时间。
- 客服入口只接受客户端配置的批准渠道；服务端只能返回是否展示和稳定渠道键。
- 退出登录遵循 KC-F-010，不因远端失败保留本地会话。
