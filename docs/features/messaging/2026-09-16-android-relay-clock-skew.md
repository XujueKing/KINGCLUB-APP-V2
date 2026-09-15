# A 手机实际接入 SUPERVM 中继

用户确认 A 恢复连接后，覆盖安装局域网 Preview/Profile 包。A/B 与电脑位于同一局域网，两台手机到测试端口的 TCP 探测成功；仅 A 更新并启动，B 未安装或触屏操作。

首次 A 公钥注册成功，但中继不断重试。真机诊断确认 `handshake message is outside its validity window`。只读采样显示 A 比电脑慢约 47–137 ms；原协议检查不允许响应签发时间晚于接收端本地时钟，导致如此小的时差也被拒绝。

SUPERVM 本地提交 `6939dc96c4d0c93c1162307c5481b9145faee32f`：签发时间允许最多 5 秒时差，保留签名、身份、重放及严格过期检查，拒绝反向有效期。Rust product_overlay 7 项测试通过，包含正负 5 秒完整加密握手、5001 ms 拒绝和到期后 1 ms 拒绝。节点可执行文件与 Android 原生库均重新编译，App 构建脚本固定到该已验证提交。

修复后 A 公钥注册成功，测试节点报告 `active_connection_count=1`、`active_session_count=1`，无新的时间窗口错误。这证明真实 Android 前台到局域网节点的 TLS 与节点身份握手成功；尚不代表 A/B 中继消息、跨公网、手机后台持续连接或区块链主网验收。

局域网包 `build/app/outputs/flutter-apk/app-preview-profile-lan.apk`：SHA256 `23FBA3B22945C1B575584CCB1AF18B2E4638A9BB76475E2B51FBC48C57B87229`。普通服务端包另存为 `app-preview-profile-service.apk`。私有节点证书和地址未写入 Git；节点运行两小时后自行停止，证书也有有效期，不能作为长期发布配置。

同时修正节点启动脚本：复用进程必须核对实际监听地址，不能把只监听电脑回环的进程误报为局域网节点。实际验证错误地址复用被拒绝，正确地址可复用。连接诊断只记录错误类型及本地状态/原生协议错误，不记录账号凭证。

远端限制：SUPERVM 的 `novovm/supervm` 拒绝 XujueKing 推送（403），该协议提交仅在本地，未声称已同步。已向用户请求仓库写权限或有权限的目标地址；没有改写远端、切换身份或覆盖远端历史。
