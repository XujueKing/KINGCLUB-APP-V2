# 视频实际上传大小提示

选视频发送从账号私有草稿进入ChatVideoSendPage，未上传时调用ChatVideoOptimizer.prepare；Android超过4MiB尝试原生编码。原生根据HDR、码率和分辨率判断是否值得压缩，插件/编码不支持可能返回原文件。当前代码路径没有发现选相册视频绕过prepare，但不能据此断言用户那次发送已执行。

发送页在prepare完成后读取实际源文件和上传文件大小，展示“已压缩：X MB → Y MB”或“上传原视频：X MB”，不以编码启动推断压缩成功。显示沿用页面次要文字样式。读取期间账号失效/页面退出不更新。

静态检查和视频发送生命周期/优化器共10项回归通过。本批未改变编码参数，未重新打包；18MB视频本次实机发送结果仍未确认，不能将旧服务端压缩记录当作新手机压缩证据。

安装更新：59b0bf4代码对应profile/preview ARM64包已adb install -r Success并启动Status ok；构建63.2秒、149.0MB，SHA256 0169e74acaea6bc36f9d51e2ccc63f604054d2ce96a72b60d62ee4365ae7235f。包含群语音权限同步修复及实际视频上传大小提示；此前待安装状态以本记录为准。实机发送/播放验收仍未确认。

## Upload chunk worker — 2026-09-15

Moved each file chunk's SHA-256, HMAC key derivation and AES-256-GCM encryption into a short-lived isolate. Previously only the full-file preflight hash ran off the UI isolate; 1MiB chunk processing could still occupy it. Worker input contains only bytes and protocol values, not uploader/session storage/network objects. Existing acknowledged chunks only calculate their verification hash. Retries rebuild ciphertext with the current renewed grant and a fresh nonce; session checks run after worker completion and before network transmission. An in-flight worker can finish after disposal but cannot send its result.

Validation: targeted analyze passed; all 10 uploader tests passed, covering lost receipts, timeouts, gateway errors, grant renewal/rejection, resumed chunks and Unicode filenames. The transport fixture decrypts actual worker ciphertext and checks the original plaintext/hash; it now also checks nonce uniqueness across transmissions. These are controlled protocol tests, not handset performance or live upload acceptance. Not yet packaged/installed.
