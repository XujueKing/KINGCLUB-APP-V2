# iOS 图标与支付成功页安装记录

- 源码提交：`a14bce178841cf583bb9463ce3dddc1dd989b16f`。
- GitHub Actions：`36497473008`，构建成功。
- 使用用户提供的 `kingclub_apple/1024X1024.png` 替换 Flutter 默认图标；源图为 1024×1024 RGB PNG，无透明通道。资源目录使用 iOS universal 图标，由 Xcode 生成各尺寸。
- 包含 `e564489d` 的独立支付成功页：服务端确认已支付后显示成功页，用户点击返回才退出。
- 下载包完成摘要、ZIP 完整性、Bundle ID、签名资源、开发描述文件和测试设备检查。
- 已通过 USB 覆盖安装至现有 iPhone，安装工具返回 `Installation succeed`；未卸载或执行清理数据操作。
- 本轮未执行真实付款，支付成功页真机效果尚待人工验收。此前用户已确认 iOS 微信支付成功。
