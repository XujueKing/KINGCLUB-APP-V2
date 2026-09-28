# 支付恢复安全整改

用户根据功能审计同意推进；仅修改既有客户端恢复流程，不新增支付接口、不执行真实交易。

## 状态规则

- 持久化记录恢复为 paid：保留已付款回执展示，不生成新请求；仅商品 scope 与当前报价一致时触发一次购物车成功回调。
- 恢复其他 scope 的订单：仅显示旧订单号/金额/状态及明确说明，不把当前商品展示为旧订单明细，不触发当前购物车回调。未终结前仅查状态、不付款；终结后返回购物车由用户重新选择。
- 恢复 expired：展示关闭状态并返回购物车，不在本页自动生成新单。
- 已提交但响应丢失，按 requestId 未查到单：同 scope 重试继续使用原幂等键。查询失败/缓存无法解析时保持阻断。
- 没有 iOS 微信支付桥、运行时缺失桥或后付费链未完成时明确说明，不允许新建支付订单；已有订单保留查询和服务端确认能力。
- SDK 返回不是支付成功；所有成功仍仅来源于服务端查询。

## 验证边界

新增替身 Widget 回归覆盖按订单号/请求号恢复成功、不同购物车待付款及已支付、幂等重试、关闭订单、iOS 查询/禁止建单、postpay 禁止建单、缺桥恢复。既有三尺寸支付页测试保留。

后付费流程、iOS SDK、订单中心与资产流水真实接入仍未实现；这些能力不能因为阻断提示已完善而标记完成。

## 本轮实际结果

- 新增恢复测试 10 项，加既有支付页三尺寸测试，共 13 项通过。
- 联合回归 9 文件、78 项通过：`live_feature_gate_test`、`live_order_payment_recovery_test`、`live_order_payment_page_test`、`commerce_cross_page_flow_test`、`payment_security_flow_test`、`account_deletion_flow_test`、`ordering_order_repository_test`、`session_registration_restore_test`、`real_login_registration_test`。
- 本次改动的 navigation、支付页及新增测试定向 analyze：No issues found；格式检查与 git diff --check 通过。
- SDK 和依赖锁文件已对齐。全仓库 analyze 仍有审计前既存的 9 条测试格式 info；未全量运行 372 个测试文件，未打包或真机验收。
- GitHub 凭据仍为无写权限账号，保持本地 main 提交，不记为已推送。
