# 2026-09-16 位置消息与无地图 App 兜底

A 真实地理编码搜索 Shanghai 返回 31.232457,121.469141（WGS84），明确确认后向授权 B 会话发送位置卡片；点开详情坐标一致。本轮未读取或发送设备当前坐标，B 未操作，不能声称 B 接收/地图验收完成。

点击在高德查看，现有 callnative=1 在未安装高德的 A 上进入浏览器 APK 下载提示（186 MB），未下载或安装。依据高德 URI 官方说明 https://developer.amap.com/api/uri-api/gettingstarted ，改为 callnative=0 使用网页标注，避免自动拉起/下载。经纬度顺序、原坐标系及转义保留；不改会话 UI 或消息协议。修复后需同设备打开该参数的真实网页核对。

同设备实测：通过 ACTION_VIEW 打开保持相同经纬度/名称/坐标系、仅 callnative=0 的 URI，截图确认 Shanghai 标记及街道地图正常加载，不自动进入下载。网页仍有高德自身打开 App 的按钮，本次未点击。截图 build/location-web-fallback-A.png 仅本机留存。此时验证的是实际 URL，修复版应用按钮仍待构建安装复核。

构建安装：Profile/preview ARM64 构建成功（Gradle 122.8 秒），原生 ELF 检查通过；APK SHA256 40691B358140E491EEEE863E2E4517FE49A0C2F61BCF2AE0B90BC189ABCDD385。A 覆盖安装 Success，lastUpdateTime 2026-09-16 07:11:04，包含 d92aa18 入群撤回前后台修复。首次启动前台仍是浏览器，未误点；再次启动后检查前台及首页。B 未操作。原生按钮从新包到网页完整链路仍需下一步验收；已验证同参数真实地图显示。
