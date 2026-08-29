# 封面调整与本地保存验收

- 日期：2026-08-29
- 设备：Android arm64 USB 真机 `e1c31301`
- 包名：`com.lingmei.kingclub.v2preview`
- 范围：UI/本地 Mock；未接入资料接口、媒体上传或生产 SDK

## 已验证

1. 编辑主页保持全黑金主题，头像为空白且无点击流程。
2. “更换封面”打开 Android 系统相册单选。
3. 选图后进入“调整封面”，可拖动图片并支持双指缩放。
4. 确认后返回编辑页显示裁剪预览，整页保存后写入应用私有 `files/profile/cover.png`。
5. `MyProfilePage` 重新创建时读取该文件；缺失或损坏时回退默认上海夜景。
6. 首页视觉基准已按当前确认版式更新；全量 293 项测试及静态检查通过。

## 证据

- [`01-installed.png`](01-installed.png)：已安装 arm64 调试包的真机画面。
- [`02-after-tap.png`](02-after-tap.png)：真机欢迎页与当前安装版本。
- [`03-cover-adjust.png`](03-cover-adjust.png)：真机黑金封面调整页。
- [`04-profile-after-restart.png`](04-profile-after-restart.png)：强制结束后回到欢迎页，证明既有 Mock 登录态不跨进程；封面文件仍保留。
- `adb run-as` 检查结果：`files/profile/cover.png` 已生成，大小 167989 bytes。

备注：当前 Mock 登录态按既有规则仅保存在内存，强制结束 App 后会先回到欢迎页；再次进入“我的”页时本地封面文件会由页面加载。此行为不属于本轮真实鉴权接入范围。
