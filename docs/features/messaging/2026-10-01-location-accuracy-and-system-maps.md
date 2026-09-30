# 当前定位与系统地图修正

用户反馈 Android / iPhone 当前定位均偏离 1–2 公里；实际在日盛·桂花城，iPhone 显示株洲开心苗苗公寓。该现场误差尚未复测，不能仅凭名称认定是坐标转换问题。

已确认的代码缺口：当前定位直接使用首次结果，容许 1000 米误差且不核对时间；反向地理编码首个 `Placemark.name` 被当成所在建筑名称，附近建筑可能因此被误标；安卓地图入口仅打开高德网页。iOS 原生 MapKit 已使用 WGS84，新发送的位置也明确保存 WGS84，不能再次强制做 GCJ02 偏移。

本次实现：两端统一请求精确定位权限、订阅短时高精度定位并淘汰过期/粗糙结果，优先等待 50 米以内的新定位，期限内仅允许最多 100 米的可用结果；取得结果后停止订阅，选点页显示估计精度、权限设置及系统地图预览入口。历史 GCJ02 与 WGS84 标记保留；安卓已安装地图优先（系统默认或选择器），高德/百度使用各自明确的坐标系参数，未知地图仅接受标准 WGS84 geo URI，没有原生地图才回退网页。iOS 查看模式调用系统地图的地点页，与导航模式区分。

范围限制：系统地图可以查看与导航，但系统未提供跨地图 App 通用的“选点并将坐标返回 KINGCLUB”接口。截图中的腾讯内嵌地图选点、附近 POI 仍需地图 SDK 配置，不能用外部地图跳转宣称已实现。现场精度仍须在精确定位授权后复测。

验证：19 项定位、选点、地图、会话失效和删除测试通过；6 个 Dart 文件静态分析无问题；Android `compilePreviewDebugKotlin` 编译成功。现场查询 A（462606d8）正式包 `com.lingmei.kingclub` 的粗略与精确定位当前均未授权，不能据此证明过去的现场坐标误差。iPhone 权限与当前坐标尚未复测。当前版本尚未覆盖安装。

参考：[Android 地图 Intent](https://developer.android.com/guide/components/intents-common#Maps)、[Apple CLLocation](https://developer.apple.com/documentation/corelocation/cllocation)、[Geolocator 精确权限](https://pub.dev/packages/geolocator)、[高德地图标注](https://lbs.amap.com/api/amap-mobile/guide/android/marker)、[百度地图调起](https://lbs.baidu.com/docs/webapi?title=mapadjustment%2Furi%2Fandriod)。
